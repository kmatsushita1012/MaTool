//
//  LocationSharingUsecase.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/20.
//

import Foundation
import Foundation
import Dependencies

final class LocationService: Sendable {

    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.locationClient) var locationClient

    private var timer: Timer?
    private(set) var locationHistory: [Status] = []
    private(set) var isTracking: Bool = false
    private(set) var interval: Interval = Interval.sample

    private var historyStreamPair = AsyncStream<[Status]>.makeStream()
    var historyStream: AsyncStream<[Status]> {
        historyStreamPair = AsyncStream<[Status]>.makeStream()
        return historyStreamPair.stream
    }
    private var continuation: AsyncStream<[Status]>.Continuation {
        historyStreamPair.continuation
    }

    func startTracking(id: String, interval: Interval) {
        guard !isTracking else { return }
        isTracking = true
        locationClient.startTracking()
        self.interval = interval
        startTimer(id, TimeInterval(interval.value))
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

    private func startTimer(_ id: String, _ interval: TimeInterval) {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.fetchLocationAndSend(id)
            }
        }
        Task {
            await self.fetchLocationAndSend(id)
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
            let result = await apiRepository.putLocation(location)
            switch result {
            case .success:
                appendHistory(.update(location))
            case .failure(let error):
                appendHistory(.apiError(Date(), error))
            }
        }
    }
    
    private func deleteLocation(_ id: String) async {
        let result = await apiRepository.deleteLocation(id)
        switch result {
        case .success:
            appendHistory(.delete(Date()))
        case .failure(let error):
            appendHistory(.apiError(Date(), error))
        }
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

