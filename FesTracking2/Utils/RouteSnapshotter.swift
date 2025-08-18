//
//  RouteSnapshotter.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/31.
//

import UIKit
@preconcurrency import MapKit

struct RouteSnapshotter: Equatable {
    let districtName: String
    let route: Route
    let filter: PointFilter
    
    init(_ route: Route, districtName : String, filter: PointFilter = .export){
        self.route = route
        self.districtName = districtName
        self.filter = filter
    }
    
    init(_ route: RouteInfo, filter: PointFilter = .export){
        self.route = route.toModel()
        self.districtName = route.districtName
        self.filter = filter
    }
    
    var points:[Point] {
        filter.apply(to: route)
    }
    
    var segments: [Segment] {
        route.segments
    }
    
    func take() async throws -> UIImage? {
        let region = makeRegion(segments.flatMap { $0.coordinates }, ratio: 1.4)
        let image = try await take(of: region, size: CGSize(width: 594, height: 420))
        return image
    }
    
    func take(of region: MKCoordinateRegion, size: CGSize) async throws -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.pointOfInterestFilter = .excludingAll
        options.size = size == .zero ? CGSize(width: 594, height: 420) : size
        
        return try? await withCheckedThrowingContinuation { continuation in
            let snapshotter = MKMapSnapshotter(options: options)
            withExtendedLifetime(snapshotter) {
                snapshotter.start { snapshot, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let snapshot = snapshot else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    var drawnRects: [CGRect] = []
                    UIGraphicsBeginImageContextWithOptions(options.size, true, 0)
                    snapshot.image.draw(at: .zero)
                    //FIXME: v3.0.0
                    drawSlopePolyline(on: snapshot)
                    drawPolylines(on: snapshot, color: UIColor.white, lineWidth: 4)
                    drawPolylines(on: snapshot, color: UIColor.blue, lineWidth: 3)
                    drawPinsAndCaptions(on: snapshot, drawnRects: &drawnRects)
                    
                    //FIXME: v3.0.0
                    drawSlopePoint(on: snapshot, drawnRects: &drawnRects)
                    
                    let titleText = """
                    \(districtName)
                    \(route.date.text(format: "m月d日")) \(route.title)
                    開始時刻 \(route.start.text)
                    終了時刻 \(route.goal.text)
                    """
                    drawTitleTextBlock(text: titleText, in: options)
                    
                    let image = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    continuation.resume(returning: image)
                }
            }
        } ?? nil
    }
    
    private func drawPolylines(on snapshot: MKMapSnapshotter.Snapshot, color: UIColor, lineWidth: CGFloat ) {
        for segment in segments {
            drawPolyline(on: snapshot, coordinates: segment.coordinates, color: color, lineWidth: lineWidth)
        }
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
        
        for (index, point) in points.enumerated() {
            let pointInSnapshot = snapshot.point(for: point.coordinate.toCL())
            pinImage.draw(at:
                CGPoint(x: pointInSnapshot.x - pinImage.size.width / 2,
                        y: pointInSnapshot.y - pinImage.size.height/2)
            )
            let caption: String = {
                var caption = "\(index + 1)"
                if let title = point.title {
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
    
    private func drawTitleTextBlock(text: String, in options: MKMapSnapshotter.Options) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left

        let font = UIFont.systemFont(ofSize: 10, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.black // 黒文字
        ]
        
        // パディングとサイズ計算
        let padding: CGFloat = 8
        let maxTextWidth = options.size.width * 0.9
        let textRect = CGRect(x: padding, y: padding, width: maxTextWidth - padding * 2, height: .greatestFiniteMagnitude)
        let boundingRect = (text as NSString).boundingRect(with: textRect.size, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)

        let backgroundRect = CGRect(x: padding,
                                    y: padding,
                                    width: boundingRect.width + padding * 2,
                                    height: boundingRect.height + padding * 2)

        // 背景を白で塗る
        UIColor.white.setFill()
        let backgroundPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 6)
        backgroundPath.fill()

        // 黒い枠線を描く
        UIColor.black.setStroke()
        backgroundPath.lineWidth = 2
        backgroundPath.stroke()

        // テキスト描画
        let textDrawRect = CGRect(x: backgroundRect.origin.x + padding,
                                  y: backgroundRect.origin.y + padding,
                                  width: boundingRect.width,
                                  height: boundingRect.height)
        (text as NSString).draw(in: textDrawRect, withAttributes: attributes)
    }

    
    func createPDF(with image: UIImage, path: String) -> URL? {
       let pdfData = NSMutableData()
       let pdfRect = CGRect(origin: .zero, size: image.size)
       UIGraphicsBeginPDFContextToData(pdfData, pdfRect, nil)
       UIGraphicsBeginPDFPage()
       image.draw(in: pdfRect)
       UIGraphicsEndPDFContext()

       let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(path)
       do {
           try pdfData.write(to: tempURL, options: .atomic)
           return tempURL
       } catch {
           return nil
       }
    }
    
    //FIXME: v3.0.0
    private func drawSlopePoint(on snapshot: MKMapSnapshotter.Snapshot, drawnRects: inout [CGRect]) {
        let toshokan = snapshot.point(for: Coordinate(latitude: 34.774803,longitude: 138.015110).toCL())
        drawCaption(
            for: "斜度5.8%",
            at: toshokan,
            pinImage: UIImage(systemName: "circle.fill")!,
            drawnRects: &drawnRects
        )
        let shinmei = snapshot.point(
            for: CLLocationCoordinate2D(
                latitude: 34.776993,
                longitude: 138.018933)
        )
        drawCaption(
            for: "斜度1.4%",
            at: shinmei,
            pinImage: UIImage(systemName: "circle.fill")!,
            drawnRects: &drawnRects
        )
    }
    private func drawSlopePolyline(on snapshot: MKMapSnapshotter.Snapshot) {
        let toshokanCoordinates = [
            Coordinate(latitude: 34.774471, longitude: 138.015110),
            Coordinate(latitude: 34.775118, longitude: 138.015131)
        ]
        drawPolyline(on: snapshot, coordinates: toshokanCoordinates, color: .orange, lineWidth: 8)
        let shinmeiCoordinates = [
            Coordinate(latitude: 34.775140, longitude: 138.018356),
            Coordinate(latitude: 34.775942, longitude: 138.018427),
            Coordinate(latitude: 34.777033, longitude: 138.018906),
            Coordinate(latitude: 34.777707, longitude: 138.019524),
            Coordinate(latitude: 34.778608, longitude: 138.019802)
        ]
        drawPolyline(on: snapshot, coordinates: shinmeiCoordinates, color: .orange, lineWidth: 8)
    }
}
