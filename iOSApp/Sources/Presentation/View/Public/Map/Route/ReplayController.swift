//
//  ReplayController.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/26.
//

import Foundation
import MapKit
import Shared

@MainActor
final class ReplayController: ObservableObject {
    
    enum State: Equatable {
        case playing(Double)
        case paused
    }

    struct Frame: Equatable {
        var annotation: FloatMapItem?
        var progress: Double
    }
    
    // MARK: - Properties
    private var timer: Timer?
    
    private var name: String
    private var coords: [Coordinate]
    private var stepDistance: CLLocationDistance
    private var interval: TimeInterval
    private(set) var state: State = .paused
    private var onEnd: (() -> Void)?
    private var index: Int = 0

    @Published private(set) var frame = Frame(annotation: nil, progress: 0)
    
    // MARK: - Init
    init(
        name: String,
        coords: [Coordinate] = [],
        stepDistance: CLLocationDistance = 10,
        interval: TimeInterval = 0.1,
        onEnd: (() -> Void)? = nil
    ) {
        self.name = name
        self.stepDistance = stepDistance
        self.interval = interval
        self.coords = Self.interpolateCoordinates(coords, step: stepDistance)
        self.index = 0
        self.onEnd = onEnd
    }
    
    // MARK: - Public Methods
    
    func prepare(coordinates: [Coordinate]?) {
        if case .playing = state  {
            stop()
        }
        updateCoordinates(coordinates)
    }
    
    func start() {
        guard !coords.isEmpty else { return }
        state = .playing(Double(index) / Double(max(coords.count-1,1)))
        publishFrame()
        startTimer()
    }
    
    func pause() {
        state = .paused
        stopTimer()
    }
    
    func stop() {
        state = .paused
        stopTimer()
        index = 0
        frame = Frame(annotation: nil, progress: 0)
    }
    
    func seek(to progress: Double) {
        guard !coords.isEmpty else { return }
        let clamped = max(0, min(1, progress))
        index = Int(Double(coords.count-1) * clamped)
        publishFrame()
        state = .playing(clamped)
        if timer == nil {
            startTimer()
        }
    }
    
    // MARK: - Private
    private func updateCoordinates(_ newCoords: [Coordinate]?) {
        if let newCoords {
            self.coords = Self.interpolateCoordinates(newCoords, step: stepDistance)
        } else {
            self.coords = []
        }
        
        self.index = 0
        if frame.annotation != nil, !coords.isEmpty {
            publishFrame()
        } else {
            frame = Frame(annotation: nil, progress: 0)
        }
    }
    
    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {  [weak self] _ in
            Task { @MainActor in
                self?.tick()
           }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        guard index + 1 < coords.count else {
            stop()
            onEnd?()
            return
        }
        index += 1
        publishFrame()
        state = .playing(Double(index) / Double(max(coords.count-1, 1)))
    }

    private func publishFrame() {
        frame = Frame(
            annotation: FloatMapItem(title: name, coordinate: coords[index], entry: nil),
            progress: Double(index) / Double(max(coords.count - 1, 1))
        )
    }
    
    // MARK: - Static interpolation
    private static func interpolateCoordinates(_ coords: [Coordinate], step: CLLocationDistance) -> [Coordinate] {
        guard coords.count > 1 else { return coords }
        
        var result: [Coordinate] = []
        var prev = coords.first!
        result.append(prev)
        
        for next in coords.dropFirst() {
            let start = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
            let end = CLLocation(latitude: next.latitude, longitude: next.longitude)
            let distance = start.distance(from: end)
            
            if distance > step {
                let steps = Int(distance / step)
                for i in 1..<steps {
                    let ratio = Double(i) / Double(steps)
                    let lat = prev.latitude + (next.latitude - prev.latitude) * ratio
                    let lon = prev.longitude + (next.longitude - prev.longitude) * ratio
                    result.append(Coordinate(latitude: lat, longitude: lon))
                }
            }
            result.append(next)
            prev = next
        }
        return result
    }
}



