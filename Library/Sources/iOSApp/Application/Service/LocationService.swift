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

actor LocationService {
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.locationProvider) var locationProvider

    private var trackingTask: Task<Void, Never>?
    private(set) var locationHistory: [Status] = []
    private(set) var interval: Interval?
    private(set) var isTracking = false
    private var lastSentAt: Date?
    private let threshold: Double = 0.95

    private var continuation: AsyncStream<[Status]>.Continuation?

    var historyStream: AsyncStream<[Status]> {
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

    func requestPermission() async {
        await locationProvider.requestPermission()
    }

    func start(id: String, interval: Interval) async {
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

    func stop(id: String) async {
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
                districtId: id,
                coordinate: Coordinate.fromCL(cllocation.coordinate),
                timestamp: Date.now
            )
            let result = await apiRepository.putLocation(location)
            switch result {
            case .success:
                appendHistory(.update(location))
            case .failure(let error):
                appendHistory(.apiError(Date(), error))
            }
        }
    }

    private func delete(_ id: String) async {
        let result = await apiRepository.deleteLocation(id)
        switch result {
        case .success:
            appendHistory(.delete(Date()))
        case .failure(let error):
            appendHistory(.apiError(Date(), error))
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



extension LocationService: DependencyKey {
    static let liveValue: LocationService = LocationService()
}

extension LocationService: TestDependencyKey {
    static let testValue: LocationService = LocationService()
}


extension DependencyValues {
    var locationService: LocationService {
        get { self[LocationService.self] }
        set { self[LocationService.self] = newValue }
    }
}

