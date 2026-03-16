import CCairo
import Dependencies
import Foundation
import Shared

enum RouteSnapshotRendererKey: DependencyKey {
    static let liveValue: RouteSnapshotRendererProtocol = CairoRouteSnapshotRenderer()
}

extension DependencyValues {
    var routeSnapshotRenderer: RouteSnapshotRendererProtocol {
        get { self[RouteSnapshotRendererKey.self] }
        set { self[RouteSnapshotRendererKey.self] = newValue }
    }
}

struct RouteSnapshotPageInput: Sendable, Equatable {
    let routeId: String
    let points: [Point]
}

protocol RouteSnapshotRendererProtocol: Sendable {
    func renderPNG(routeId: String, points: [Point]) throws -> Data
    func renderPDF(pages: [RouteSnapshotPageInput]) throws -> Data
}

struct CairoRouteSnapshotRenderer: RouteSnapshotRendererProtocol {
    private let canvasWidth: Int32 = 594
    private let canvasHeight: Int32 = 420

    func renderPNG(routeId: String, points: [Point]) throws -> Data {
        let url = tempURL(ext: "png")
        let surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, canvasWidth, canvasHeight)
        defer { cairo_surface_destroy(surface) }

        try validate(surface: surface)

        let context = cairo_create(surface)
        defer { cairo_destroy(context) }

        drawPage(context: context, routeId: routeId, points: points)

        let status = cairo_surface_write_to_png(surface, url.path)
        guard status == CAIRO_STATUS_SUCCESS else {
            throw Error.internalServerError("PNGの出力に失敗しました")
        }
        defer { try? FileManager.default.removeItem(at: url) }
        return try Data(contentsOf: url)
    }

    func renderPDF(pages: [RouteSnapshotPageInput]) throws -> Data {
        let url = tempURL(ext: "pdf")
        let surface = cairo_pdf_surface_create(url.path, Double(canvasWidth), Double(canvasHeight))
        defer { cairo_surface_destroy(surface) }

        try validate(surface: surface)

        let context = cairo_create(surface)
        defer { cairo_destroy(context) }

        for (index, page) in pages.enumerated() {
            drawPage(context: context, routeId: page.routeId, points: page.points)
            if index < pages.count - 1 {
                cairo_show_page(context)
            }
        }

        cairo_surface_finish(surface)
        defer { try? FileManager.default.removeItem(at: url) }
        return try Data(contentsOf: url)
    }
}

private extension CairoRouteSnapshotRenderer {
    func tempURL(ext: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("route-snapshot-\(UUID().uuidString).\(ext)")
    }

    func validate(surface: OpaquePointer?) throws {
        let status = cairo_surface_status(surface)
        guard status == CAIRO_STATUS_SUCCESS else {
            throw Error.internalServerError("cairo surfaceの作成に失敗しました")
        }
    }

    func drawPage(context: OpaquePointer?, routeId: String, points: [Point]) {
        drawBackground(context: context)
        drawRoute(context: context, points: points)
        drawTitle(context: context, routeId: routeId)
    }

    func drawBackground(context: OpaquePointer?) {
        cairo_set_source_rgb(context, 0.92, 0.96, 1.0)
        cairo_rectangle(context, 0, 0, Double(canvasWidth), Double(canvasHeight))
        cairo_fill(context)
    }

    func drawTitle(context: OpaquePointer?, routeId: String) {
        cairo_set_source_rgb(context, 0.05, 0.12, 0.24)
        cairo_select_font_face(context, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
        cairo_set_font_size(context, 16)
        cairo_move_to(context, 16, 28)
        cairo_show_text(context, routeId)
    }

    func drawRoute(context: OpaquePointer?, points: [Point]) {
        let coordinates = points.map(\.coordinate)
        guard coordinates.count > 1 else { return }

        let projected = project(coordinates: coordinates)

        cairo_set_source_rgb(context, 0.05, 0.32, 0.88)
        cairo_set_line_width(context, 4)
        cairo_move_to(context, projected[0].x, projected[0].y)
        for point in projected.dropFirst() {
            cairo_line_to(context, point.x, point.y)
        }
        cairo_stroke(context)

        for point in projected {
            cairo_set_source_rgb(context, 0.0, 0.55, 1.0)
            cairo_arc(context, point.x, point.y, 3.0, 0.0, Double.pi * 2)
            cairo_fill(context)
        }
    }

    func project(coordinates: [Coordinate]) -> [(x: Double, y: Double)] {
        let minLat = coordinates.map(\.latitude).min() ?? 0
        let maxLat = coordinates.map(\.latitude).max() ?? 0
        let minLon = coordinates.map(\.longitude).min() ?? 0
        let maxLon = coordinates.map(\.longitude).max() ?? 0

        let padding = 24.0
        let width = Double(canvasWidth) - padding * 2
        let height = Double(canvasHeight) - padding * 2

        let lonRange = max(maxLon - minLon, 0.000_001)
        let latRange = max(maxLat - minLat, 0.000_001)

        return coordinates.map { coordinate in
            let x = padding + ((coordinate.longitude - minLon) / lonRange) * width
            let y = Double(canvasHeight) - padding - ((coordinate.latitude - minLat) / latRange) * height
            return (x, y)
        }
    }
}
