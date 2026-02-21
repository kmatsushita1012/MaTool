import MapKit
import Shared

public extension Coordinate {
    func toCL() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func fromCL(_ coordinate: CLLocationCoordinate2D) -> Coordinate {
        Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
