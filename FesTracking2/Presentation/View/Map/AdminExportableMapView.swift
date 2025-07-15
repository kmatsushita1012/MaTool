//
//  AdminRouteExportMapView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/09.
//

import SwiftUI
import MapKit

struct AdminRouteExportMapView: UIViewRepresentable {
    var points: [Point]
    var segments: [Segment]
    @Binding var region: MKCoordinateRegion?

    @Binding var wholeSnapshot: UIImage?
    @Binding var partialSnapshot: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        if let region = region{
            mapView.setRegion(region, animated: false)
        }
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        // アノテーション追加
        for (index, point) in points.enumerated() {
            let annotation = PointAnnotation(point, type: .time(index) )
            annotation.coordinate = point.coordinate.toCL()
            mapView.addAnnotation(annotation)
        }

        // ポリライン追加
        for segment in segments {
            let polyline = SegmentPolyline(coordinates: segment.coordinates.map({$0.toCL()}), count: segment.coordinates.count)
            polyline.segment = segment
            mapView.addOverlay(polyline)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AdminRouteExportMapView
        var hasSetRegion = false

        init(_ parent: AdminRouteExportMapView) {
            self.parent = parent
            
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? SegmentPolyline {
                let renderer = MKPolylineRenderer(overlay: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 4
                renderer.alpha = 0.8
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil // 現在地はデフォルトのまま
            }
            let identifier = "AnnotationView"

            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.displayPriority = .required
            if #available(iOS 11.0, *) {
                (annotationView as? MKMarkerAnnotationView)?.clusteringIdentifier = nil
            }
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = .red
                markerView.canShowCallout = true
            }
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
            parent.exportVisibleMapToPDF(mapView: mapView)
            if parent.wholeSnapshot == nil {
                parent.exportFullMapToPDF(mapView: mapView)
            }
        }
    }
    
    func exportFullMapToPDF(mapView: MKMapView) {
        let region = makeRegion(segments.flatMap { $0.coordinates }, ratio: 1.4)
        takeSnapshot(of: region, size: CGSize(width: 594, height: 420)) { image in
            guard let image = image else {
                return
            }
            DispatchQueue.main.async {
                self.wholeSnapshot = image
            }
        }
    }

    func exportVisibleMapToPDF(mapView: MKMapView) {
        let region = mapView.region
        let size = mapView.frame.size
        takeSnapshot(of: region, size: size) { image in
            guard let image = image else {
                return
            }
            DispatchQueue.main.async {
                self.partialSnapshot = image
            }
        }
    }

    
    
    private func takeSnapshot(of region: MKCoordinateRegion, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.pointOfInterestFilter = .excludingAll
        options.size = size == .zero ? CGSize(width: 594, height: 420) : size
        let snapshotter = MKMapSnapshotter(options: options)
        withExtendedLifetime(snapshotter) {
            snapshotter.start { snapshot, error in
                guard let snapshot = snapshot else {
                    completion(nil)
                    return
                }
                
                UIGraphicsBeginImageContextWithOptions(options.size, true, 0)
                snapshot.image.draw(at: .zero)
                drawPolylines(on: snapshot,color: UIColor.white,lineWidth: 4)
                drawPolylines(on: snapshot,color: UIColor.blue,lineWidth: 3)
                drawPinsAndCaptions(on: snapshot)
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                completion(image)
            }
        }
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
}

