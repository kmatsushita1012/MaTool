//
//  LocationSharingUsecase.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/20.
//

import Foundation
import Dependencies
import CoreLocation
import Shared

// MARK: - Dependencies
enum LocationServiceKey: DependencyKey {
    static let liveValue: any LocationServiceProtocol = LocationService()
}

extension DependencyValues {
    var locationService: any LocationServiceProtocol {
        get { self[LocationServiceKey.self] }
        set { self[LocationServiceKey.self] = newValue }
    }
}

// MARK: - LocationServiceProtocol
protocol LocationServiceProtocol: Sendable {
    func getLocationHistory() async -> [Status]
    func getInterval() async -> Interval?
    func getIsTracking() async -> Bool
    func historyStream() async -> AsyncStream<[Status]>
    func requestPermission() async -> Void
    func start(id: String, interval: Interval) async -> Void
    func stop(id: String) async -> Void
    func getLocation() async -> AsyncValue<CLLocation>
}

// MARK: - LocationService
actor LocationService: LocationServiceProtocol {
    
    @Dependency(LocationDataFetcherKey.self) var dataFetcher
    @Dependency(\.locationProvider) var locationProvider

    private var trackingTask: Task<Void, Never>?
    private var locationHistory: [Status] = []
    private var interval: Interval?
    private var isTracking = false
    private var lastSentAt: Date?
    private let threshold: Double = 0.95

    private var continuation: AsyncStream<[Status]>.Continuation?
    
    func getLocationHistory() async -> [Status] {
        locationHistory
    }
    
    func getInterval() async -> Interval? {
        interval
    }
    
    func getIsTracking() async -> Bool {
        isTracking
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
        await locationProvider.requestPermission()
    }

    func start(id: String, interval: Interval) async -> Void {
        guard trackingTask == nil else { return }

        self.interval = interval
        lastSentAt = nil
        isTracking = true
        
        await locationProvider.startTracking(backgroundUpdatesAllowed: true){ result in
            await self.sendIfNeeded(id: id, result: result)
        }

        trackingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let locationResult = await locationProvider.getLocation()
                await self.sendIfNeeded(id: id, result: locationResult)
                try? await Task.sleep(nanoseconds: UInt64(interval.value * 1_000_000_000))
            }
        }
    }

    func stop(id: String) async -> Void {
        trackingTask?.cancel()
        trackingTask = nil
        isTracking = false
        lastSentAt = nil
        
        await locationProvider.stopTracking()
        await delete(id)
    }

    func getLocation() async -> AsyncValue<CLLocation> {
        await locationProvider.getLocation()
    }
    
    private func sendIfNeeded(id: String, result: AsyncValue<CLLocation>) async {
            guard let interval else { return }
            let now = Date()
            let elapsed = lastSentAt.map { now.timeIntervalSince($0) } ?? .infinity
            if elapsed >= Double(interval.value) * threshold {
                lastSentAt = now
                await send(id: id, result: result)
            }
        }

    private func send(id: String, result: AsyncValue<CLLocation>) async {
        switch result {
        case .loading:
            appendHistory(.loading(Date()))
        case .failure:
            appendHistory(.locationError(Date()))
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
            } catch let error as APIError {
                appendHistory(.apiError(Date(), error))
            } catch {
                appendHistory(.apiError(Date(), .unknown(message: error.localizedDescription)))
            }
        }
    }

    private func delete(_ id: String) async {
        do {
            try await dataFetcher.delete(districtId: id)
            appendHistory(.delete(Date()))
        } catch let error as APIError {
            appendHistory(.apiError(Date(), error))
        } catch {
            appendHistory(.apiError(Date(), .unknown(message: error.localizedDescription)))
        }
    }
    
    private func clearContinuation() {
        continuation = nil
    }

    private func appendHistory(_ status: Status) {
        locationHistory.append(status)
        continuation?.yield(locationHistory)
    }
}
