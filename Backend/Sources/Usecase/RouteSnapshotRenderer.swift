import CLibCairo
import CPango
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
        drawTitle(context: context, routeId: routeId, pointsCount: points.count)
    }

    func drawBackground(context: OpaquePointer?) {
        cairo_set_source_rgb(context, 0.92, 0.96, 1.0)
        cairo_rectangle(context, 0, 0, Double(canvasWidth), Double(canvasHeight))
        cairo_fill(context)
    }

    func drawTitle(context: OpaquePointer?, routeId: String, pointsCount: Int) {
        guard let context else { return }

        let title = "\(routeId)"
        let subtitle = "ポイント数: \(pointsCount)"

        cairo_set_source_rgb(context, 0.05, 0.12, 0.24)
        drawPangoText(
            context: context,
            text: title,
            fontDescription: "Noto Sans CJK JP Bold 16",
            x: 16,
            y: 12
        )
        cairo_set_source_rgb(context, 0.18, 0.22, 0.30)
        drawPangoText(
            context: context,
            text: subtitle,
            fontDescription: "Noto Sans CJK JP 12",
            x: 16,
            y: 34
        )
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

    func drawPangoText(
        context: OpaquePointer,
        text: String,
        fontDescription: String,
        x: Double,
        y: Double
    ) {
        guard let layout = pango_cairo_create_layout(context) else { return }
        defer { g_object_unref(layout) }

        if let font = pango_font_description_from_string(fontDescription) {
            pango_layout_set_font_description(layout, font)
            pango_font_description_free(font)
        }

        text.withCString { cText in
            pango_layout_set_text(layout, cText, -1)
        }

        let maxWidth = Int((Double(canvasWidth) - 32.0) * Double(PANGO_SCALE))
        pango_layout_set_width(layout, Int32(maxWidth))
        pango_layout_set_wrap(layout, PANGO_WRAP_WORD_CHAR)
        pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END)

        cairo_move_to(context, x, y)
        pango_cairo_show_layout(context, layout)
    }
}
