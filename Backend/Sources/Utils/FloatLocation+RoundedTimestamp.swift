import Foundation
import Shared

extension FloatLocation {
    func roundedTimestamp() -> Self {
        .init(
            id: id,
            districtId: districtId,
            coordinate: coordinate,
            timestamp: Date(timeIntervalSince1970: timestamp.timeIntervalSince1970.rounded())
        )
    }
}

extension Optional where Wrapped == FloatLocation {
    func roundedTimestamp() -> Self {
        self?.roundedTimestamp()
    }
}

extension Array where Element == FloatLocation {
    func roundedTimestamp() -> Self {
        map { $0.roundedTimestamp() }
    }
}

extension LaunchFestivalPack {
    func roundedLocationTimestamps() -> Self {
        .init(
            festival: festival,
            districts: districts,
            periods: periods,
            locations: locations.roundedTimestamp(),
            checkpoints: checkpoints,
            hazardSections: hazardSections
        )
    }
}
