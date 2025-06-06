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
    let region: MKCoordinateRegion? = nil

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
        }else if !context.coordinator.hasSetRegion, !points.isEmpty {
           let avgLatitude = points.map { $0.coordinate.latitude }.reduce(0, +) / Double(points.count)
           let avgLongitude = points.map { $0.coordinate.longitude }.reduce(0, +) / Double(points.count)
           let center = CLLocationCoordinate2D(latitude: avgLatitude, longitude: avgLongitude)
           let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta))
           mapView.setRegion(region, animated: false)
           context.coordinator.hasSetRegion = true
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
            parent.exportVisibleMapToPDF(mapView: mapView)
            if parent.wholeSnapshot == nil {
                parent.exportFullMapToPDF(mapView: mapView)
            }
        }
    }
    
    func exportFullMapToPDF(mapView: MKMapView) {
        let region = calculateRegionIncludingAll()
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

    private func calculateRegionIncludingAll() -> MKCoordinateRegion {
        let allCoordinates = points.map { $0.coordinate.toCL() }
        let minLat = allCoordinates.map { $0.latitude }.min() ?? 0
        let maxLat = allCoordinates.map { $0.latitude }.max() ?? 0
        let minLon = allCoordinates.map { $0.longitude }.min() ?? 0
        let maxLon = allCoordinates.map { $0.longitude }.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.4,
            longitudeDelta: (maxLon - minLon) * 1.4
        )
        return MKCoordinateRegion(center: center, span: span)
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

        // 描画候補方向（下・上・右・左）
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
                // 背景
                context?.setFillColor(UIColor.white.cgColor)
                context?.fill(rect)

                // テキスト
                caption.draw(at: CGPoint(x: rect.origin.x + padding,
                                         y: rect.origin.y + padding),
                             withAttributes: attributes)

                drawnRects.append(rect)
                return
            }
        }
        // すべて衝突した場合は描画しない
    }

}
