import Foundation
import Shared

struct FloatLocationResponse: Encodable {
    let id: String
    let districtId: String
    let coordinate: Coordinate
    let timestamp: Int64

    init(_ location: FloatLocation) {
        id = location.id
        districtId = location.districtId
        coordinate = location.coordinate
        timestamp = Int64(location.timestamp.timeIntervalSince1970.rounded())
    }
}

extension Optional where Wrapped == FloatLocation {
    func asResponse() -> FloatLocationResponse? {
        self.map(FloatLocationResponse.init)
    }
}

extension Array where Element == FloatLocation {
    func asResponse() -> [FloatLocationResponse] {
        map(FloatLocationResponse.init)
    }
}

struct LaunchFestivalPackResponse: Encodable {
    let festival: Festival
    let districts: [District]
    let periods: [Period]
    let locations: [FloatLocationResponse]
    let checkpoints: [Checkpoint]
    let hazardSections: [HazardSection]

    init(_ pack: LaunchFestivalPack) {
        festival = pack.festival
        districts = pack.districts
        periods = pack.periods
        locations = pack.locations.asResponse()
        checkpoints = pack.checkpoints
        hazardSections = pack.hazardSections
    }
}
