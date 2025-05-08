//
//  LocationSharingUsecase.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/20.
//

import Foundation
import Foundation
import Dependencies

final class LocationSharingUseCase: Sendable {
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.apiClient) var apiClient

    private var timer: Timer?
    private var locationHistory: [Status] = []
    private(set) var isTracking: Bool = false

    private var historyStreamPair = AsyncStream<[Status]>.makeStream()
    var historyStream: AsyncStream<[Status]> {
        historyStreamPair = AsyncStream<[Status]>.makeStream()
        return historyStreamPair.stream
    }
    private var continuation: AsyncStream<[Status]>.Continuation {
        historyStreamPair.continuation
    }

    func startTracking(id: String,interval: TimeInterval = 1.0) {
        guard !isTracking else { return }
        isTracking = true
        locationClient.startTracking()
        startTimer(id,interval)
    }

    func stopTracking(id: String) {
        guard isTracking else { return }
        locationClient.stopTracking()
        stopTimer()
        isTracking = false
        Task {
            await deleteLocation(id)
        }
    }

    private func startTimer(_ id: String,_ interval: TimeInterval) {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.fetchLocationAndSend(id)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func appendHistory(_ status: Status) {
        locationHistory.append(status)
        continuation.yield(locationHistory)
    }

    private func fetchLocationAndSend(_ id: String) async {
        let locationResult = locationClient.getLocation()
        switch locationResult {
        case .loading:
            appendHistory(.loading(Date()))
        case .failure(_):
            appendHistory(.locationError(Date()))
        case .success(let cllocation):
            let location = Location(districtId: id, coordinate: Coordinate.fromCL(cllocation.coordinate), timestamp: Date())
            let result = await apiClient.postLocation(location,"")
            switch result {
            case .success:
                appendHistory(.update(location))
            case .failure:
                appendHistory(.apiError(Date()))
            }
        }
    }
    
    private func deleteLocation(_ id: String) async {
        let result = await apiClient.deleteLocation(id,"")
        switch result {
        case .success:
            appendHistory(.delete(Date()))
        case .failure:
            appendHistory(.apiError(Date()))
        }
    }

    func getLocationHistory() -> [Status] {
        locationHistory
    }
}

extension LocationSharingUseCase: DependencyKey {
    static let liveValue: LocationSharingUseCase = LocationSharingUseCase()
}

extension LocationSharingUseCase: TestDependencyKey {
    static let testValue: LocationSharingUseCase = LocationSharingUseCase()
}


extension DependencyValues {
    var locationSharingUseCase: LocationSharingUseCase {
        get { self[LocationSharingUseCase.self] }
        set { self[LocationSharingUseCase.self] = newValue }
    }
}

