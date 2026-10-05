//
//  LocationUsecase.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/20.
//

import Foundation
import Dependencies
import CoreLocation
import Shared
import os

struct LocationPermissionState: Sendable, Equatable {
    let authorizationStatus: CLAuthorizationStatus
    let hasRequestedAlwaysLocationPermission: Bool

    var isLocationAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isAlwaysAuthorized: Bool {
        authorizationStatus == .authorizedAlways
    }
}

enum LocationTrackingStartResult: Sendable, Equatable {
    case started(LocationPermissionState)
    case permissionRequired(LocationPermissionState)
    case locationServicesDisabled
}

// MARK: - Dependencies
enum LocationUsecaseKey: DependencyKey {
    static let liveValue: any LocationUsecaseProtocol = LocationUsecase()
}

extension DependencyValues {
    var locationUsecase: any LocationUsecaseProtocol {
        get { self[LocationUsecaseKey.self] }
        set { self[LocationUsecaseKey.self] = newValue }
  }
}

// MARK: - LocationUsecaseProtocol
protocol LocationUsecaseProtocol: Sendable {
    func getLocationHistory() async -> [Status]
    func getInterval() async -> Interval?
    func getIsTracking() async -> Bool
    func historyStream() async -> AsyncStream<[Status]>
    func requestPermission() async -> Void
    func locationPermissionState() async -> LocationPermissionState
    func start(id: String, interval: Interval) async -> LocationTrackingStartResult
    func stop(id: String) async -> Void
    func getLocation() async -> AsyncValue<CLLocation>
}

// MARK: - LocationUsecase
actor LocationUsecase: LocationUsecaseProtocol {
    
    @Dependency(LocationDataFetcherKey.self) var dataFetcher
    @Dependency(\.broadcastLocationProvider) var broadcastLocationProvider
    @Dependency(UserDefaltsManagerKey.self) var userDefaults

    private var trackingTask: Task<Void, Never>?
    private var locationHistory: [Status] = []
    private var interval: Interval?
    private let sendingState = OSAllocatedUnfairLock(initialState: LocationSendingState())
    // await中にactorは再入可能なため、非同期の開始・停止処理全体を直列化する。
    // 同期ロックだけではprovider呼び出しの順序をawait越しに保てない。
    private var lifecycleLockIsHeld = false
    private var lifecycleLockWaiters: [CheckedContinuation<Void, Never>] = []
    // 停止前に開始した保存を削除より先に完了させ、停止後の行の復活を防ぐ。
    private var pendingLocationWrites = 0
    private var pendingLocationWriteWaiters: [CheckedContinuation<Void, Never>] = []

    private var continuation: AsyncStream<[Status]>.Continuation?
    
    func getLocationHistory() async -> [Status] {
        locationHistory
    }
    
    func getInterval() async -> Interval? {
        interval
    }
    
    func getIsTracking() async -> Bool {
        sendingState.withLock { $0.sessionID != nil }
    }

    func historyStream() async -> AsyncStream<[Status]> {
        AsyncStream { continuation in
            // 最新 continuation に置き換える
            self.continuation = continuation

            // 終了時にクリーンアップ
            continuation.onTermination = { @Sendable _ in
                Task { await self.clearContinuation() }
            }

            // 初回は現状の履歴を流す
            continuation.yield(locationHistory)
        }
    }

    func requestPermission() async -> Void {
        await broadcastLocationProvider.requestPermission { [self] in
            await markAlwaysLocationPermissionRequested()
        }
    }

    func locationPermissionState() async -> LocationPermissionState {
        let authorizationStatus = await broadcastLocationProvider.authorizationStatus()
        return LocationPermissionState(
            authorizationStatus: authorizationStatus,
            hasRequestedAlwaysLocationPermission: userDefaults.hasRequestedAlwaysLocationPermission
        )
    }

    func start(id: String, interval: Interval) async -> LocationTrackingStartResult {
        await acquireLifecycleLock()
        defer { releaseLifecycleLock() }

        let permissionState = await locationPermissionState()
        guard permissionState.isAlwaysAuthorized else {
            return .permissionRequired(permissionState)
        }
        guard trackingTask == nil else {
            return .started(permissionState)
        }
        guard await broadcastLocationProvider.isLocationServicesEnabled() else {
            appendHistory(.locationError(Date(), locationErrorDetail(LocationError.servicesDisabled)))
            return .locationServicesDisabled
        }

        self.interval = interval
        let sessionID = UUID()
        sendingState.withLock {
            $0.sessionID = sessionID
            $0.lastSentAt = nil
        }
        
        await broadcastLocationProvider.startTracking { result in
            await self.sendIfNeeded(id: id, sessionID: sessionID, result: result)
        }

        trackingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let locationResult = await broadcastLocationProvider.getLocation()
                await self.sendIfNeeded(id: id, sessionID: sessionID, result: locationResult)
                try? await Task.sleep(nanoseconds: UInt64(interval.value * 1_000_000_000))
            }
        }
        return .started(permissionState)
    }

    func stop(id: String) async -> Void {
        await acquireLifecycleLock()
        defer { releaseLifecycleLock() }

        trackingTask?.cancel()
        trackingTask = nil
        sendingState.withLock {
            $0.sessionID = nil
            $0.lastSentAt = nil
        }
        interval = nil
        
        await broadcastLocationProvider.stopTracking()
        await waitForPendingLocationWrites()
        await delete(id)
    }

    func getLocation() async -> AsyncValue<CLLocation> {
        await broadcastLocationProvider.getLocation()
    }
    
    private func sendIfNeeded(id: String, sessionID: UUID, result: AsyncValue<CLLocation>) async {
        guard let interval else { return }
        let now = Date()
        let isLocationSuccess: Bool
        if case .success = result {
            isLocationSuccess = true
        } else {
            isLocationSuccess = false
        }
        let shouldSend = sendingState.withLock { state in
            guard state.sessionID == sessionID else { return false }
            guard isLocationSuccess else { return true }

            let elapsed = state.lastSentAt.map { now.timeIntervalSince($0) } ?? .infinity
            guard elapsed >= Double(interval.value) * 0.95 else { return false }

            // 送信できた位置情報だけを更新間隔の基準にする。
            state.lastSentAt = now
            return true
        }
        guard shouldSend else { return }

        switch result {
        case .success:
            pendingLocationWrites += 1
            await send(id: id, result: result)
            finishPendingLocationWrite()
        case .loading, .failure:
            // 読み込み中・取得失敗は履歴へ記録するだけで、位置情報の更新間隔には影響させない。
            await send(id: id, result: result)
        }
    }

    private func send(id: String, result: AsyncValue<CLLocation>) async {
        switch result {
        case .loading:
            appendHistory(.loading(Date()))
        case .failure(let error):
            appendHistory(.locationError(Date(), locationErrorDetail(error)))
        case .success(let cllocation):
            let location = FloatLocation(
                id: UUID().uuidString,
                districtId: id,
                coordinate: Coordinate.fromCL(cllocation.coordinate),
                timestamp: Date.now
            )
            do {
                try await dataFetcher.update(location)
                appendHistory(.update(location))
            } catch let error as AppError {
                appendHistory(.apiError(Date(), error))
            } catch {
                appendHistory(.apiError(Date(), error.asAppError))
            }
        }
    }

    private func delete(_ id: String) async {
        do {
            try await dataFetcher.delete(districtId: id)
            appendHistory(.delete(Date()))
        } catch let error as AppError {
            appendHistory(.apiError(Date(), error))
        } catch {
            appendHistory(.apiError(Date(), error.asAppError))
        }
    }
    
    private func clearContinuation() {
        continuation = nil
    }

    private func acquireLifecycleLock() async {
        guard lifecycleLockIsHeld else {
            lifecycleLockIsHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            lifecycleLockWaiters.append(continuation)
        }
    }

    private func releaseLifecycleLock() {
        guard !lifecycleLockWaiters.isEmpty else {
            lifecycleLockIsHeld = false
            return
        }
        lifecycleLockWaiters.removeFirst().resume()
    }

    private func waitForPendingLocationWrites() async {
        guard pendingLocationWrites > 0 else { return }
        await withCheckedContinuation { continuation in
            pendingLocationWriteWaiters.append(continuation)
        }
    }

    private func finishPendingLocationWrite() {
        pendingLocationWrites -= 1
        guard pendingLocationWrites == 0 else { return }
        let waiters = pendingLocationWriteWaiters
        pendingLocationWriteWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func markAlwaysLocationPermissionRequested() {
        userDefaults.setHasRequestedAlwaysLocationPermission(true)
    }

    private func locationErrorDetail(_ error: Error) -> String {
#if DEBUG
        let localizedDescription = error.localizedDescription
        let reflectedDescription = String(reflecting: error)
        if localizedDescription == reflectedDescription {
            return reflectedDescription
        }
        return "\(localizedDescription)\n\(reflectedDescription)"
#else
        return ""
#endif
    }

    private func appendHistory(_ status: Status) {
        locationHistory.append(status)
        continuation?.yield(locationHistory)
    }
}

private struct LocationSendingState: Sendable {
    var sessionID: UUID?
    var lastSentAt: Date?
}
