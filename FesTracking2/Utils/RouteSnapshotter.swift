//
//  RouteSnapshotter.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/31.
//

import UIKit
@preconcurrency import MapKit

struct RouteSnapshotter: Equatable {

    let route: Route
    let filter: PointFilter
    
    init(_ route: Route, filter: PointFilter = .export){
        self.route = route
        self.filter = filter
    }
    
    init(_ route: RouteInfo, filter: PointFilter = .export){
        self.route = route.toModel()
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
                    
                    UIGraphicsBeginImageContextWithOptions(options.size, true, 0)
                    snapshot.image.draw(at: .zero)
                    drawPolylines(on: snapshot, color: UIColor.white, lineWidth: 4)
                    drawPolylines(on: snapshot, color: UIColor.blue, lineWidth: 3)
                    drawPinsAndCaptions(on: snapshot)
                    let image = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    continuation.resume(returning: image)
                }
            }
        } ?? nil
    }

    
    private func drawPolylines(on snapshot: MKMapSnapshotter.Snapshot, color: UIColor, lineWidth: CGFloat ) {
        for segment in segments {
            guard segment.coordinates.count > 1 else { continue }

            let path = UIBezierPath()
            let start = snapshot.point(for: segment.coordinates[0].toCL())
            path.move(to: start)

            for coord in segment.coordinates.dropFirst() {
                let point = snapshot.point(for: coord.toCL())
                path.addLine(to: point)
            }
            color.setStroke()
            path.lineWidth = lineWidth
            path.stroke()
        }
    }
    
    private func drawPinsAndCaptions(on snapshot: MKMapSnapshotter.Snapshot) {
        var drawnRects: [CGRect] = []
        let originalImage = UIImage(systemName: "circle.fill")!
        let smallSize = CGSize(width: 10, height: 10)
        let pinImage = UIGraphicsImageRenderer(size: smallSize).image { _ in
            originalImage.withTintColor(.red, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(origin: .zero, size: smallSize))
        }
        
        for (index, point) in points.enumerated() {
            let pointInSnapshot = snapshot.point(for: point.coordinate.toCL())
            pinImage.draw(at:
                CGPoint(x: pointInSnapshot.x - pinImage.size.width / 2,
                        y: pointInSnapshot.y - pinImage.size.height/2)
            )
            drawCaption(for: point, index: index, at: pointInSnapshot, pinImage: pinImage, drawnRects: &drawnRects)
        }
    }

    private func drawCaption(for point: Point,index: Int, at location: CGPoint, pinImage: UIImage, drawnRects: inout [CGRect]) {
        var caption = "\(index + 1)"
        if let title = point.title{
            caption += ":\(title)"
        }
        if let time = point.time?.text{
            caption += "\n\(time)"
        }
        
        let font = UIFont.boldSystemFont(ofSize: 8)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]

        let textSize = caption.size(withAttributes: attributes)
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
            // TODO: 調整
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
                //背景
                context?.setFillColor(UIColor(white: 1.0, alpha: 0.7).cgColor)
                context?.fill(rect)
                context?.setStrokeColor(UIColor.red.cgColor)
                context?.setLineWidth(0.5)
                context?.stroke(rect)
                //キャプション
                caption.draw(at: CGPoint(x: rect.origin.x + padding,
                                         y: rect.origin.y + padding),
                             withAttributes: attributes)
                drawnRects.append(rect)
                return
            }
        }
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
}
