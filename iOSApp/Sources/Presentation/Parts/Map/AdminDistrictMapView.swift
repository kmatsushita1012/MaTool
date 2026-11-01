import MapKit
import Shared
import SwiftUI

struct AdminDistrictMap: View {
    var coordinates: [Coordinate]?
    var isShownPolygon: Bool
    @Binding var region: MKCoordinateRegion?
    var onMapLongPress: (Coordinate) -> Void
    @State private var position: MapCameraPosition

    init(coordinates: [Coordinate]?, isShownPolygon: Bool, region: Binding<MKCoordinateRegion?>, onMapLongPress: @escaping (Coordinate) -> Void) {
        self.coordinates = coordinates
        self.isShownPolygon = isShownPolygon
        self._region = region
        self.onMapLongPress = onMapLongPress
        self._position = State(initialValue: region.wrappedValue.map(MapCameraPosition.region) ?? .automatic)
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                ForEach(Array((coordinates ?? []).enumerated()), id: \.offset) { _, coordinate in
                    Marker("", coordinate: coordinate.toCL())
                }
                if isShownPolygon, let coordinates, coordinates.count >= 3 {
                    MapPolygon(coordinates: coordinates.map { $0.toCL() })
                        .foregroundStyle(.blue.opacity(0.2))
                        .stroke(.blue, lineWidth: 2)
                }
            }
            .onMapCameraChange(frequency: .onEnd) { region = $0.region }
            .simultaneousGesture(
                LongPressGesture().sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        if case let .second(true, drag?) = value,
                           let coordinate = proxy.convert(drag.startLocation, from: .local) {
                            onMapLongPress(.fromCL(coordinate))
                        }
                    }
            )
        }
    }
}
