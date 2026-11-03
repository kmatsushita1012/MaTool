import MapKit
import Shared
import SwiftUI

struct InfoMapView: View {
    var base: Coordinate?
    var baseTitle: String = "会所"
    var area: [Coordinate]
    var isMapMovementEnabled = true
    @Binding var region: MKCoordinateRegion?
    @State private var position: MapCameraPosition

    init(base: Coordinate?, baseTitle: String = "会所", area: [Coordinate], isMapMovementEnabled: Bool = true, region: Binding<MKCoordinateRegion?>) {
        self.base = base
        self.baseTitle = baseTitle
        self.area = area
        self.isMapMovementEnabled = isMapMovementEnabled
        self._region = region
        self._position = State(initialValue: region.wrappedValue.map(MapCameraPosition.region) ?? .automatic)
    }

    var body: some View {
        Map(position: $position, interactionModes: isMapMovementEnabled ? .all : [.zoom, .rotate, .pitch]) {
            if let base {
                Marker(baseTitle, coordinate: base.toCL())
                    .tint(.red)
            }
            MapPolygon(coordinates: area.map { $0.toCL() })
                .foregroundStyle(.blue.opacity(0.2))
                .stroke(.blue, lineWidth: 2)
        }
        .onMapCameraChange(frequency: .onEnd) { region = $0.region }
    }
}
