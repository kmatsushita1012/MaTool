import MapKit
import Shared
import SwiftUI

struct MapView: View {
    enum Style: Entity {
        case `public`, admin, edit
    }

    let style: Style
    let points: [PointEntry]
    let districtAreaOverlays: [DistrictAreaOverlay]
    let floats: [FloatEntry]
    let floatAnnotation: FloatMapItem?
    let showsDistrictAreaOverlay: Bool
    @Binding var region: MKCoordinateRegion
    @Binding var size: CGSize?
    let pointTapped: (PointEntry) -> Void
    let floatTapped: (FloatEntry) -> Void
    let onLongPress: (Coordinate) -> Void
    @State private var position: MapCameraPosition
    @State private var displayedRegion: MKCoordinateRegion
    @State private var selectedPoint: Point.ID?

    init(style: Style, points: [PointEntry] = [], districtAreaOverlays: [DistrictAreaOverlay] = [], showsDistrictAreaOverlay: Bool = false, floatAnnotation: FloatMapItem? = nil, region: Binding<MKCoordinateRegion>, size: Binding<CGSize?> = .constant(nil), pointTapped: @escaping (PointEntry) -> Void = { _ in }, floatTapped: @escaping (FloatEntry) -> Void = { _ in }, onLongPress: @escaping (Coordinate) -> Void = { _ in }) {
        self.init(style: style, points: points, floats: [], districtAreaOverlays: districtAreaOverlays, showsDistrictAreaOverlay: showsDistrictAreaOverlay, floatAnnotation: floatAnnotation, region: region, size: size, pointTapped: pointTapped, floatTapped: floatTapped, onLongPress: onLongPress)
    }

    init(style: Style, points: [PointEntry] = [], floats: [FloatEntry], districtAreaOverlays: [DistrictAreaOverlay] = [], showsDistrictAreaOverlay: Bool = false, region: Binding<MKCoordinateRegion>, size: Binding<CGSize?> = .constant(nil), pointTapped: @escaping (PointEntry) -> Void = { _ in }, floatTapped: @escaping (FloatEntry) -> Void = { _ in }, onLongPress: @escaping (Coordinate) -> Void = { _ in }) {
        self.init(style: style, points: points, floats: floats, districtAreaOverlays: districtAreaOverlays, showsDistrictAreaOverlay: showsDistrictAreaOverlay, floatAnnotation: nil, region: region, size: size, pointTapped: pointTapped, floatTapped: floatTapped, onLongPress: onLongPress)
    }

    private init(style: Style, points: [PointEntry], floats: [FloatEntry], districtAreaOverlays: [DistrictAreaOverlay], showsDistrictAreaOverlay: Bool, floatAnnotation: FloatMapItem?, region: Binding<MKCoordinateRegion>, size: Binding<CGSize?>, pointTapped: @escaping (PointEntry) -> Void, floatTapped: @escaping (FloatEntry) -> Void, onLongPress: @escaping (Coordinate) -> Void) {
        self.style = style
        self.points = points
        self.floats = floats
        self.districtAreaOverlays = districtAreaOverlays
        self.showsDistrictAreaOverlay = showsDistrictAreaOverlay
        self.floatAnnotation = floatAnnotation
        self._region = region
        self._size = size
        self.pointTapped = pointTapped
        self.floatTapped = floatTapped
        self.onLongPress = onLongPress
        self._position = State(initialValue: .region(region.wrappedValue))
        self._displayedRegion = State(initialValue: region.wrappedValue)
    }

    var body: some View {
        GeometryReader { geometry in
            MapReader { proxy in
                Map(position: $position, selection: $selectedPoint) {
                    UserAnnotation()
                    if showsDistrictAreaOverlay {
                        ForEach(districtAreaOverlays) { overlay in
                            let color = Color(uiColor: districtAreaPalette[overlay.colorIndex % districtAreaPalette.count])
                            MapPolygon(coordinates: overlay.area.map { $0.toCL() })
                                .foregroundStyle(color.opacity(0.2))
                                .stroke(color.opacity(0.9), lineWidth: 1.5)
                            Annotation(overlay.districtName, coordinate: overlay.center.toCL()) {
                                Text(overlay.districtName)
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(color.opacity(0.8), in: Capsule())
                                    .overlay(Capsule().stroke(.white, lineWidth: 1))
                            }
                            .annotationTitles(.hidden)
                        }
                    }
                    ForEach(Array(splitPoints().enumerated()), id: \.offset) { index, segment in
                        MapPolyline(coordinates: segment.map { $0.toCL() })
                            .stroke(index.isMultiple(of: 2) ? .blue : .green, lineWidth: 4)
                    }
                    ForEach(points.filter(style: style)) { point in
                        PointMapMarker(point: point)
                            .tag(point.id)
                    }
                    if let floatAnnotation {
                        Annotation(
                            floatAnnotation.title,
                            coordinate: floatAnnotation.coordinate.toCL(),
                            anchor: .center
                        ) {
                            FloatMapLabel(title: floatAnnotation.title, isInteractive: floatAnnotation.entry != nil) {
                                if let entry = floatAnnotation.entry { floatTapped(entry) }
                            }
                            .offset(y: 8)
                            .zIndex(1)
                        }
                        .annotationTitles(.hidden)
                    } else {
                        ForEach(floats) { float in
                            Annotation(
                                float.district.name,
                                coordinate: float.floatLocation.coordinate.toCL(),
                                anchor: .center
                            ) {
                                FloatMapLabel(title: float.district.name, isInteractive: true) {
                                    floatTapped(float)
                                }
                                .offset(y: 8)
                                .zIndex(1)
                            }
                            .annotationTitles(.hidden)
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: style == .public ? .excluding(.excludedForPublic) : .including(.includedForAdmin)))
                .mapControlVisibility(.hidden)
                .onChange(of: selectedPoint) { _, id in
                    guard let id, let point = points.first(where: { $0.id == id }) else { return }
                    selectedPoint = nil
                    pointTapped(point)
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    displayedRegion = context.region
                    region = context.region
                }
                .onChange(of: region) { _, newRegion in
                    guard !sameRegion(newRegion, displayedRegion) else { return }
                    displayedRegion = newRegion
                    withAnimation { position = .region(newRegion) }
                }
                .simultaneousGesture(
                    LongPressGesture().sequenced(before: DragGesture(minimumDistance: 0))
                        .onEnded { value in
                            if case let .second(true, drag?) = value,
                               let coordinate = proxy.convert(drag.startLocation, from: .local) {
                                onLongPress(.fromCL(coordinate))
                            }
                        }
                )
            }
            .onAppear { size = geometry.size }
            .onChange(of: geometry.size) { _, newSize in size = newSize }
        }
    }

    private func splitPoints() -> [[Coordinate]] {
        var result: [[Coordinate]] = []
        var current: [Coordinate] = []
        for point in points {
            current.append(point.coordinate)
            if point.point.isBoundary {
                result.append(current)
                current = [point.coordinate]
            }
        }
        result.append(current)
        return result.filter { $0.count >= 2 }
    }

    private func sameRegion(_ lhs: MKCoordinateRegion, _ rhs: MKCoordinateRegion) -> Bool {
        abs(lhs.center.latitude - rhs.center.latitude) <= 0.00001 &&
        abs(lhs.center.longitude - rhs.center.longitude) <= 0.00001 &&
        abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta) <= 0.00001 &&
        abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta) <= 0.00001
    }
}

private struct PointMapMarker: MapContent {
    let point: PointEntry

    var body: some MapContent {
        if let anchor = point.anchor {
            Marker(point.title ?? "", monogram: Text(anchor.glyph), coordinate: point.coordinate.toCL())
                .annotationTitles(.hidden)
                .tint(Color.annotation)
        } else if point.performance != nil {
            Marker(point.title ?? "", systemImage: "figure.dance", coordinate: point.coordinate.toCL())
                .tint(Color.annotation)
        } else if point.checkpoint != nil {
            Marker(point.title ?? "", systemImage: "arrow.up.and.down.and.arrow.left.and.right", coordinate: point.coordinate.toCL())
                .tint(Color.annotation)
        } else {
            Marker(point.title ?? "", coordinate: point.coordinate.toCL())
                .tint(Color.annotation)
        }
    }
}

private extension Shared.Anchor {
    var glyph: String {
        switch self {
        case .start: "発"
        case .end: "着"
        case .rest: "休"
        }
    }
}

private struct FloatMapLabel: View {
    let title: String
    let isInteractive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: "circle.circle.fill")
                    .font(.title)
                    .foregroundStyle(.red)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .shadow(color: Color(uiColor: .systemBackground), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .allowsHitTesting(isInteractive)
    }
}

private extension Array where Element == PointEntry {
    func filter(style: MapView.Style) -> Self {
        switch style {
        case .public: filter { $0.anchor != nil || $0.performance != nil }
        case .admin: filter { $0.anchor != nil || $0.checkpoint != nil }
        case .edit: self
        }
    }
}

extension MapView: Equatable {
    static func == (lhs: MapView, rhs: MapView) -> Bool {
        lhs.floatAnnotation == rhs.floatAnnotation && lhs.style == rhs.style && lhs.points == rhs.points &&
        lhs.districtAreaOverlays == rhs.districtAreaOverlays && lhs.floats == rhs.floats &&
        lhs.showsDistrictAreaOverlay == rhs.showsDistrictAreaOverlay && lhs.region == rhs.region
    }
}

extension Array where Element == MKPointOfInterestCategory {
    static var excludedForPublic: [MKPointOfInterestCategory] {
        [.nightlife, .restaurant, .beauty]
    }

    static var includedForAdmin: [MKPointOfInterestCategory] {
        [.airport, .aquarium, .bank, .beach, .campground, .fireStation, .hospital, .library,
         .museum, .nationalPark, .park, .publicTransport, .police, .postOffice, .restroom,
         .stadium, .school, .university, .zoo, .castle, .conventionCenter, .fortress,
         .fairground, .golf, .miniGolf, .kayaking, .landmark, .mailbox, .musicVenue, .nationalMonument]
    }
}
