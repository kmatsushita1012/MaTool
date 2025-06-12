//
//  ExportableMap.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/09.
//

import SwiftUI
import MapKit

struct ExportableMap: UIViewRepresentable {
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
        for point in points {
            let annotation = PointAnnotation(point, type: .time )
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
        var parent: ExportableMap
        var hasSetRegion = false

        init(_ parent: ExportableMap) {
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
        let region = makeRegion(points.map{ $0.coordinate }, ratio: 1.4)
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
                drawPolylines(on: snapshot,color: UIColor.white,lineWidth: 8)
                drawPolylines(on: snapshot,color: UIColor.blue,lineWidth: 4)
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
        var drawnRects: [CGRect] = [] // ローカルで衝突回避用に保持

        for (index, point) in points.enumerated() {
            let pointInSnapshot = snapshot.point(for: point.coordinate.toCL())

            guard let pinImage = UIImage(systemName: "mappin")?.withTintColor(.red, renderingMode: .alwaysOriginal) else { continue }
            pinImage.draw(at: CGPoint(x: pointInSnapshot.x - pinImage.size.width / 2,
                                      y: pointInSnapshot.y - pinImage.size.height))

            drawCaption(for: point, at: pointInSnapshot, pinImage: pinImage, drawnRects: &drawnRects)
        }
    }

    private func drawCaption(for point: Point, at location: CGPoint, pinImage: UIImage, drawnRects: inout [CGRect]) {
        let title = point.title ?? ""
        let time = point.time?.text ?? ""
        let caption = (title + time) as NSString
        let font = UIFont.boldSystemFont(ofSize: 12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]

        let textSize = caption.size(withAttributes: attributes)
        let padding: CGFloat = 4
        let context = UIGraphicsGetCurrentContext()
        
        let directions: [(dx: CGFloat, dy: CGFloat)] = [
            (0, +1), (0, -1), (+1, 0), (-1, 0)
        ]

        for direction in directions {
            let origin = CGPoint(
                x: location.x + direction.dx * (pinImage.size.width + padding),
                y: location.y + direction.dy * (pinImage.size.height + padding)
            )

            let rect = CGRect(
                x: origin.x - textSize.width / 2 - padding,
                y: origin.y - textSize.height / 2 - padding,
                width: textSize.width + padding * 2,
                height: textSize.height + padding * 2
            )

            if drawnRects.allSatisfy({ !$0.intersects(rect) }) {
                context?.setFillColor(UIColor.white.cgColor)
                context?.fill(rect)
                caption.draw(at: CGPoint(x: rect.origin.x + padding,
                                         y: rect.origin.y + padding),
                             withAttributes: attributes)
                drawnRects.append(rect)
                return
            }
        }
    }

}
