//
//  RouteSnapshotter.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/31.
//

import UIKit
@preconcurrency import MapKit
import Shared
import SQLiteData

struct RouteMapCaptionLayoutPlanner {
    private struct LayoutSearchFailure: Error {}

    struct CaptionInput: Sendable {
        let text: String
        let anchor: CGPoint
        let textSize: CGSize
        let padding: CGFloat
        let margin: CGFloat
    }

    struct CaptionPlacement: Sendable {
        let text: String
        let anchor: CGPoint
        let rect: CGRect
        let connectorPoint: CGPoint
    }

    struct TitlePlacement: Sendable {
        let backgroundRect: CGRect
        let textRect: CGRect
    }

    private let directions: [(dx: CGFloat, dy: CGFloat)] = [
        (+1, -1), (+1, +1), (-1, +1), (-1, -1)
    ]

    func placeCaptions(inputs: [CaptionInput], occupiedRects: [CGRect]) -> [CaptionPlacement] {
        do {
            return try resolveCaptions(inputs: inputs, index: 0, occupiedRects: occupiedRects)
        } catch is LayoutSearchFailure {
            return makeFallbackPlacements(inputs: inputs, index: 0)
        } catch {
            return makeFallbackPlacements(inputs: inputs, index: 0)
        }
    }

    func placeTitle(
        text: String,
        canvasSize: CGSize,
        occupiedRects: [CGRect],
        attributes: [NSAttributedString.Key: Any],
        padding: CGFloat
    ) -> TitlePlacement {
        let maxTextWidth = canvasSize.width * 0.9
        let textBounds = CGRect(
            x: 0,
            y: 0,
            width: maxTextWidth - padding * 2,
            height: .greatestFiniteMagnitude
        )
        let boundingRect = (text as NSString).boundingRect(
            with: textBounds.size,
            options: .usesLineFragmentOrigin,
            attributes: attributes,
            context: nil
        )
        let backgroundSize = CGSize(
            width: boundingRect.width + padding * 2,
            height: boundingRect.height + padding * 2
        )
        let candidates: [CGRect] = [
            CGRect(origin: CGPoint(x: padding, y: padding), size: backgroundSize),
            CGRect(
                origin: CGPoint(x: padding, y: canvasSize.height - backgroundSize.height - padding),
                size: backgroundSize
            ),
            CGRect(
                origin: CGPoint(x: canvasSize.width - backgroundSize.width - padding, y: padding),
                size: backgroundSize
            ),
            CGRect(
                origin: CGPoint(
                    x: canvasSize.width - backgroundSize.width - padding,
                    y: canvasSize.height - backgroundSize.height - padding
                ),
                size: backgroundSize
            )
        ]

        let backgroundRect = candidates.first { candidate in
            occupiedRects.allSatisfy { !$0.intersects(candidate) }
        } ?? candidates[0]

        let textRect = CGRect(
            x: backgroundRect.origin.x + padding,
            y: backgroundRect.origin.y + padding,
            width: boundingRect.width,
            height: boundingRect.height
        )
        return TitlePlacement(backgroundRect: backgroundRect, textRect: textRect)
    }

    private func resolveCaptions(
        inputs: [CaptionInput],
        index: Int,
        occupiedRects: [CGRect]
    ) throws -> [CaptionPlacement] {
        guard index < inputs.count else {
            return []
        }

        let input = inputs[index]
        let candidates = makeCandidates(for: input)

        for candidate in candidates {
            guard occupiedRects.allSatisfy({ !$0.intersects(candidate.rect) }) else { continue }
            do {
                let tail = try resolveCaptions(
                    inputs: inputs,
                    index: index + 1,
                    occupiedRects: occupiedRects + [candidate.rect]
                )
                return [candidate] + tail
            } catch is LayoutSearchFailure {
                continue
            }
        }

        throw LayoutSearchFailure()
    }

    private func makeFallbackPlacements(
        inputs: [CaptionInput],
        index: Int
    ) -> [CaptionPlacement] {
        guard index < inputs.count else {
            return []
        }

        let fallback = makeCandidates(for: inputs[index]).last!
        return [fallback] + makeFallbackPlacements(
            inputs: inputs,
            index: index + 1
        )
    }

    private func makeCandidates(for input: CaptionInput) -> [CaptionPlacement] {
        directions.map { direction in
            let halfWidth = input.textSize.width / 2 + input.padding
            let halfHeight = input.textSize.height / 2 + input.padding
            let center = CGPoint(
                x: input.anchor.x + direction.dx * (input.margin + halfWidth),
                y: input.anchor.y + direction.dy * (input.margin + halfHeight)
            )
            let rect = CGRect(
                x: center.x - halfWidth,
                y: center.y - halfHeight,
                width: input.textSize.width + input.padding * 2,
                height: input.textSize.height + input.padding * 2
            )
            let connectorPoint = CGPoint(
                x: input.anchor.x + direction.dx * input.margin,
                y: input.anchor.y + direction.dy * input.margin
            )
            return CaptionPlacement(
                text: input.text,
                anchor: input.anchor,
                rect: rect,
                connectorPoint: connectorPoint
            )
        }
    }
}

@MainActor
struct RouteSnapshotter: Equatable {
    var route: Route
    var period: Period
    var points: [Point]
    var district: District
    var hazardSections: [HazardSection]
    
    init (_ route: Route) throws {
        let points: [Point] = FetchAll(routeId: route.id).wrappedValue
        try self.init(route: route, points: points)
    }
    
    init (route: Route, points: [Point]) throws {
        guard let district: District = FetchOne(District.find(route.districtId)).wrappedValue,
              let period: Period = FetchOne(Period.find(route.periodId)).wrappedValue else {
            throw AppError.export(.notFound("必要な情報の取得に失敗しました。"))
        }
        self.district = district
        self.period = period
        self.route = route
        self.points = points
        self.hazardSections = FetchAll(festivalId: district.festivalId).wrappedValue
    }
    
    private var coordinates: [Coordinate] {
        points.map { $0.coordinate }
    }
    
    func take(path: String? = nil) async throws -> (UIImage, URL) {
        let path = path ?? "\(district.name)_\(period.path).pdf"
        let region = makeRegion(coordinates, ratio: 1.4)
        let (image, url) = try await take(of: region, size: Self.a4size, path: path)
        return (image, url)
    }
    
    func take() async throws -> UIImage {
        let region = makeRegion(coordinates, ratio: 1.4)
        let image = try await take(of: region, size: Self.a4size)
        return image
    }
    
    func take(of region: MKCoordinateRegion, size: CGSize, path: String? = nil) async throws -> (UIImage, URL) {
        let path =  path ?? "\(district.name)_\(period.path)_Part.pdf"
        let image = try await take(of: region, size: size)
        let url = try createPDF(with: image, path: path)
        return (image, url)
    }
    
    private func take(of region: MKCoordinateRegion, size: CGSize) async throws -> UIImage {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.pointOfInterestFilter = .excludingAll
        options.size = size == .zero ? CGSize(width: 594, height: 420) : size
        options.traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .light)
        ])
        
        let image: UIImage = try await withCheckedThrowingContinuation { continuation in
            let snapshotter = MKMapSnapshotter(options: options)
            withExtendedLifetime(snapshotter) {
                snapshotter.start { snapshot, error in
                    if let error = error {
                        continuation.resume(throwing: error.asAppError)
                        return
                    }
                    guard let snapshot = snapshot else {
                        continuation.resume(throwing: AppError.export(.conflict("Snapshotterサービスが利用できません。")))
                        return
                    }
                    
                    let pinImage = makePinImage()
                    let pointCaptions = makePointCaptionInputs(on: snapshot, pinSize: pinImage.size)
                    let pinRects = pointCaptions.map(\.pinRect)
                    let hazardCaptions = makeHazardCaptionInputs(on: snapshot)
                    let planner = RouteMapCaptionLayoutPlanner()
                    let captionPlacements = planner.placeCaptions(
                        inputs: pointCaptions.map(\.captionInput) + hazardCaptions,
                        occupiedRects: pinRects
                    )
                    let titleText = """
                    \(district.name)
                    \(period.text(dateFormat: "y年m月d日 (w)"))
                    開始時刻 \(points.first?.time?.text ?? period.start.text)
                    終了時刻 \(points.last?.time?.text ?? period.end.text)
                    """
                    let titleAttributes = titleTextAttributes()
                    let titlePlacement = planner.placeTitle(
                        text: titleText,
                        canvasSize: options.size,
                        occupiedRects: pinRects + captionPlacements.map(\.rect),
                        attributes: titleAttributes,
                        padding: titleBlockPadding
                    )
                    UIGraphicsBeginImageContextWithOptions(options.size, true, 0)
                    defer {
                        UIGraphicsEndImageContext()
                    }
                    snapshot.image.draw(at: .zero)
                    drawHazardSectionPolylines(on: snapshot)
                    drawPolylines(on: snapshot, color: .white, lineWidth: 4)
                    drawBoundaryPolylines(on: snapshot, lineWidth: 3)
                    drawPins(pointCaptions.map(\.pinRect), pinImage: pinImage)
                    drawCaptions(captionPlacements)
                    drawTitleTextBlock(
                        text: titleText,
                        placement: titlePlacement,
                        attributes: titleAttributes
                    )
                    
                    guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
                        continuation.resume(throwing: AppError.export(.conflict("地図の画像を作成できませんでした。")))
                        return
                    }
                    
                    continuation.resume(returning: image)
                }
            }
        }
        return image
    }
    
    private func drawPolylines(on snapshot: MKMapSnapshotter.Snapshot, color: UIColor, lineWidth: CGFloat ) {
        drawPolyline(on: snapshot, coordinates: coordinates, color: color, lineWidth: lineWidth)
    }

    private func drawBoundaryPolylines(on snapshot: MKMapSnapshotter.Snapshot, lineWidth: CGFloat) {
        let segments = splitCoordinatesByBoundary()
        for (index, segment) in segments.enumerated() {
            let color: UIColor = (index % 2 == 0) ? .systemBlue : .systemGreen
            drawPolyline(on: snapshot, coordinates: segment, color: color, lineWidth: lineWidth)
        }
    }

    private func splitCoordinatesByBoundary() -> [[Coordinate]] {
        let coords = coordinates
        guard points.count == coords.count else { return [coords] }

        var result: [[Coordinate]] = []
        var current: [Coordinate] = []

        for (index, coord) in coords.enumerated() {
            current.append(coord)

            let isBoundary = points[index].isBoundary
            if isBoundary && !current.isEmpty {
                result.append(current)
                current = [coord]
            }
        }

        if !current.isEmpty { result.append(current) }
        return result.filter { $0.count >= 2 }
    }
    
    private func drawPolyline(on snapshot: MKMapSnapshotter.Snapshot, coordinates: [Coordinate], color: UIColor, lineWidth: CGFloat ) {
        guard coordinates.count > 1 else { return }

        let path = UIBezierPath()
        let start = snapshot.point(for: coordinates[0].toCL())
        path.move(to: start)

        for coord in coordinates.dropFirst() {
            let point = snapshot.point(for: coord.toCL())
            path.addLine(to: point)
        }
        color.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }

    private func makePinImage() -> UIImage {
        let originalImage = UIImage(systemName: "circle.fill")!
        let smallSize = CGSize(width: 10, height: 10)
        return UIGraphicsImageRenderer(size: smallSize).image { _ in
            originalImage
                .withTintColor(.red, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(origin: .zero, size: smallSize))
        }
    }

    private func drawPins(_ pinRects: [CGRect], pinImage: UIImage) {
        for rect in pinRects {
            pinImage.draw(in: rect)
        }
    }

    private func makePointCaptionInputs(
        on snapshot: MKMapSnapshotter.Snapshot,
        pinSize: CGSize
    ) -> [(pinRect: CGRect, captionInput: RouteMapCaptionLayoutPlanner.CaptionInput)] {
        let filtered = points.filter{ $0.checkpointId != nil || $0.anchor != nil }
        let attributes = captionTextAttributes()
        return filtered.enumerated().map { index, point in
            let pointInSnapshot = snapshot.point(for: point.coordinate.toCL())
            let caption: String = {
                var caption = "\(index + 1)"
                if let title = makeTitle(point) {
                    caption += ":\(title)"
                }
                if let time = point.time?.text {
                    caption += "\n\(time)"
                }
                return caption
            }()
            let textSize = (caption as NSString).size(withAttributes: attributes)
            let pinRect = CGRect(
                x: pointInSnapshot.x - pinSize.width / 2,
                y: pointInSnapshot.y - pinSize.height / 2,
                width: pinSize.width,
                height: pinSize.height
            )
            let captionInput = RouteMapCaptionLayoutPlanner.CaptionInput(
                text: caption,
                anchor: pointInSnapshot,
                textSize: textSize,
                padding: captionPadding,
                margin: captionMargin
            )
            return (pinRect: pinRect, captionInput: captionInput)
        }
    }

    private func makeHazardCaptionInputs(
        on snapshot: MKMapSnapshotter.Snapshot
    ) -> [RouteMapCaptionLayoutPlanner.CaptionInput] {
        let attributes = captionTextAttributes()
        return hazardSections.compactMap { section in
            guard !section.title.isEmpty else { return nil }
            let coordinates = section.coordinates
            guard !coordinates.isEmpty else { return nil }

            let labelCoordinate = coordinates[coordinates.count / 2]
            let point = snapshot.point(for: labelCoordinate.toCL())
            let textSize = (section.title as NSString).size(withAttributes: attributes)
            return RouteMapCaptionLayoutPlanner.CaptionInput(
                text: section.title,
                anchor: point,
                textSize: textSize,
                padding: captionPadding,
                margin: captionMargin
            )
        }
    }
    
    private func makeTitle(_ point: Point) -> String? {
        if let checkpointId = point.checkpointId,
           let checkpoint = FetchOne(Checkpoint.find(checkpointId)).wrappedValue {
            checkpoint.name
        } else if let anchor = point.anchor{
            anchor.text
        } else {
            nil
        }

    }

    private func drawCaptions(_ placements: [RouteMapCaptionLayoutPlanner.CaptionPlacement]) {
        let attributes = captionTextAttributes()
        let context = UIGraphicsGetCurrentContext()

        for placement in placements {
            context?.setStrokeColor(UIColor.red.cgColor)
            context?.setLineWidth(1.0)
            context?.beginPath()
            context?.move(to: placement.anchor)
            context?.addLine(to: placement.connectorPoint)
            context?.strokePath()

            context?.setFillColor(UIColor(white: 1.0, alpha: 0.8).cgColor)
            context?.fill(placement.rect)
            context?.setStrokeColor(UIColor.red.cgColor)
            context?.setLineWidth(0.5)
            context?.stroke(placement.rect)

            placement.text.draw(
                at: CGPoint(
                    x: placement.rect.origin.x + captionPadding,
                    y: placement.rect.origin.y + captionPadding
                ),
                withAttributes: attributes
            )
        }
    }

    private func captionTextAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: UIFont.boldSystemFont(ofSize: 8),
            .foregroundColor: UIColor.black
        ]
    }

    private func titleTextAttributes() -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left

        return [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.black
        ]
    }

    private func drawTitleTextBlock(
        text: String,
        placement: RouteMapCaptionLayoutPlanner.TitlePlacement,
        attributes: [NSAttributedString.Key: Any]
    ) {
        UIColor(white: 1.0, alpha: 0.8).setFill()
        let backgroundPath = UIBezierPath(roundedRect: placement.backgroundRect, cornerRadius: 6)
        backgroundPath.fill()
        
        UIColor.black.setStroke()
        backgroundPath.lineWidth = 2
        backgroundPath.stroke()
        
        (text as NSString).draw(in: placement.textRect, withAttributes: attributes)
    }
    
    func createPDF(with image: UIImage, path: String) throws -> URL {
        let renderer = PDFRenderer(path: path)
        renderer.addPage(with: image)
        let url = renderer.finalize()
        return url
    }

    private func drawHazardSectionPolylines(on snapshot: MKMapSnapshotter.Snapshot) {
        for section in hazardSections {
            let coordinates = section.coordinates
            guard coordinates.count > 1 else { continue }
            drawPolyline(on: snapshot, coordinates: coordinates, color: .orange, lineWidth: 8)
        }
    }
    
    private let captionPadding: CGFloat = 2
    private let captionMargin: CGFloat = 5
    private let titleBlockPadding: CGFloat = 8
    static let a4size = CGSize(width: 594, height: 420)
}
