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

@MainActor
struct RouteSnapshotter: Equatable {
    enum Error: Swift.Error {
        case notFound
        case snapshotterNotAvailable
        case imageCreationFailed
    }
    
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
            throw Error.notFound
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
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let snapshot = snapshot else {
                        continuation.resume(throwing: Self.Error.snapshotterNotAvailable)
                        return
                    }
                    
                    var drawnRects: [CGRect] = []
                    UIGraphicsBeginImageContextWithOptions(options.size, true, 0)
                    defer {
                        UIGraphicsEndImageContext()
                    }
                    snapshot.image.draw(at: .zero)
                    drawHazardSectionPolylines(on: snapshot)
                    drawPolylines(on: snapshot, color: .white, lineWidth: 4)
                    drawBoundaryPolylines(on: snapshot, lineWidth: 3)
                    drawPinsAndCaptions(on: snapshot, drawnRects: &drawnRects)
                    
                    drawHazardSectionCaptions(on: snapshot, drawnRects: &drawnRects)
                    
                    let titleText = """
                    \(district.name)
                    \(period.text(dateFormat: "y年m月d日 (w)"))
                    開始時刻 \(points.first?.time?.text ?? period.start.text)
                    終了時刻 \(points.last?.time?.text ?? period.end.text)
                    """
                    drawTitleTextBlock(text: titleText, in: options, drawnRects: &drawnRects)
                    
                    guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
                        continuation.resume(throwing: Self.Error.imageCreationFailed)
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
    
    private func drawPinsAndCaptions(on snapshot: MKMapSnapshotter.Snapshot, drawnRects: inout [CGRect]) {
        let originalImage = UIImage(systemName: "circle.fill")!
        let smallSize = CGSize(width: 10, height: 10)
        let pinImage = UIGraphicsImageRenderer(size: smallSize).image { _ in
            originalImage
                .withTintColor(.red, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(origin: .zero, size: smallSize))
        }
        
        let filtered = points.filter{ $0.checkpointId != nil || $0.anchor != nil }
        
        for (index, point) in filtered.enumerated() {
            let pointInSnapshot = snapshot.point(for: point.coordinate.toCL())
            pinImage.draw(at:
                CGPoint(x: pointInSnapshot.x - pinImage.size.width / 2,
                        y: pointInSnapshot.y - pinImage.size.height/2)
            )
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

            drawCaption(for: caption, at: pointInSnapshot, pinImage: pinImage, drawnRects: &drawnRects)
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

    private func drawCaption(for text: String, at location: CGPoint, pinImage: UIImage, drawnRects: inout [CGRect]) {
        
        
        let font = UIFont.boldSystemFont(ofSize: 8)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]

        let textSize = text.size(withAttributes: attributes)
        let padding: CGFloat = 2
        let margin: CGFloat = 5
        let context = UIGraphicsGetCurrentContext()
        
        let directions: [(dx: CGFloat, dy: CGFloat)] = [
            (+1, -1), (+1, +1), (-1, +1), (-1, -1)
        ]
        for direction in directions {
            let halfWidth = textSize.width / 2 + padding
            let halfHeight = textSize.height / 2 + padding
            let center = CGPoint(
                x: location.x + direction.dx * (margin + halfWidth),
                y: location.y + direction.dy * (margin + halfHeight)
            )
            let rect = CGRect(
                x: center.x - halfWidth ,
                y: center.y - halfHeight,
                width: textSize.width + padding * 2,
                height: textSize.height + padding * 2
            )

            if drawnRects.allSatisfy({ !$0.intersects(rect) }) {
                // 吹き出し線
                context?.setStrokeColor(UIColor.red.cgColor)
                context?.setLineWidth(1.0)
                context?.beginPath()
                context?.move(to: location)
                let point = CGPoint(
                    x: location.x + direction.dx * margin,
                    y: location.y + direction.dy * margin
                )
                context?.addLine(to: point)
                context?.strokePath()
                // 背景
                context?.setFillColor(UIColor(white: 1.0, alpha: 0.8).cgColor)
                context?.fill(rect)
                context?.setStrokeColor(UIColor.red.cgColor)
                context?.setLineWidth(0.5)
                context?.stroke(rect)
                // キャプション
                text.draw(at: CGPoint(x: rect.origin.x + padding,
                                         y: rect.origin.y + padding),
                             withAttributes: attributes)
                drawnRects.append(rect)
                return
            }
        }
    }
    
    private func drawTitleTextBlock(text: String, in options: MKMapSnapshotter.Options, drawnRects: inout [CGRect]) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left

        let font = UIFont.systemFont(ofSize: 10, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.black
        ]
        
        let padding: CGFloat = 8
        let maxTextWidth = options.size.width * 0.9
        let textRect = CGRect(x: 0, y: 0, width: maxTextWidth - padding * 2, height: .greatestFiniteMagnitude)
        let boundingRect = (text as NSString).boundingRect(with: textRect.size, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)

        let backgroundSize = CGSize(width: boundingRect.width + padding * 2,
                                    height: boundingRect.height + padding * 2)
        
        let candidates: [CGPoint] = [
            CGPoint(x: padding, y: padding),
            CGPoint(x: padding, y: options.size.height - backgroundSize.height - padding),
            CGPoint(x: options.size.width - backgroundSize.width - padding, y: padding),
            CGPoint(x: options.size.width - backgroundSize.width - padding, y: options.size.height - backgroundSize.height - padding)
        ]

        var finalBackgroundRect: CGRect?
        for point in candidates {
            let candidateRect = CGRect(origin: point, size: backgroundSize)
            if !drawnRects.contains(where: { $0.intersects(candidateRect) }) {
                finalBackgroundRect = candidateRect
                drawnRects.append(candidateRect)
                break
            }
        }

        
        let backgroundRect = finalBackgroundRect ?? CGRect(origin: CGPoint(x: padding, y: padding), size: backgroundSize)
        
        UIColor(white: 1.0, alpha: 0.8).setFill()
        let backgroundPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 6)
        backgroundPath.fill()
        
        UIColor.black.setStroke()
        backgroundPath.lineWidth = 2
        backgroundPath.stroke()
        
        let textDrawRect = CGRect(x: backgroundRect.origin.x + padding,
                                  y: backgroundRect.origin.y + padding,
                                  width: boundingRect.width,
                                  height: boundingRect.height)
        (text as NSString).draw(in: textDrawRect, withAttributes: attributes)
    }
    
    func createPDF(with image: UIImage, path: String) throws -> URL {
        let renderer = PDFRenderer(path: path)
        renderer.addPage(with: image)
        let url = renderer.finalize()
        return url
    }
    
    private func drawHazardSectionCaptions(on snapshot: MKMapSnapshotter.Snapshot, drawnRects: inout [CGRect]) {
        let pinImage = UIImage(systemName: "circle.fill")!
        for section in hazardSections {
            guard !section.title.isEmpty else { continue }
            let coordinates = section.coordinates
            guard !coordinates.isEmpty else { continue }

            let labelCoordinate = coordinates[coordinates.count / 2]
            let point = snapshot.point(for: labelCoordinate.toCL())
            drawCaption(for: section.title, at: point, pinImage: pinImage, drawnRects: &drawnRects)
        }
    }

    private func drawHazardSectionPolylines(on snapshot: MKMapSnapshotter.Snapshot) {
        for section in hazardSections {
            let coordinates = section.coordinates
            guard coordinates.count > 1 else { continue }
            drawPolyline(on: snapshot, coordinates: coordinates, color: .orange, lineWidth: 8)
        }
    }
    
    static let a4size = CGSize(width: 594, height: 420)
}

extension RouteSnapshotter.Error {
    var localizedDescription: String {
        switch self {
        case .notFound:
            "必要な情報の取得に失敗しました。"
        case .imageCreationFailed:
            "地図の画像を作成できませんでした。"
        case .snapshotterNotAvailable:
            "Snapshotterサービスが利用できません。"
        }
    }
}
