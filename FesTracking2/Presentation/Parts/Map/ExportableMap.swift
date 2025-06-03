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

    @Binding var mapSnapshot: UIImage?

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

            // 全てのアノテーションを常に表示
            annotationView?.displayPriority = .required

            // クラスタリング無効化（密接アノテーションも表示させるため）
            if #available(iOS 11.0, *) {
                (annotationView as? MKMarkerAnnotationView)?.clusteringIdentifier = nil
            }

            // 見た目調整（任意）
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = .red
                markerView.canShowCallout = true
            }

            return annotationView
        }

        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.takeSnapshot(mapView: mapView)
        }
    }
    
    private func takeSnapshot(mapView: MKMapView) {
        let options = MKMapSnapshotter.Options()
        options.region = mapView.region
        options.pointOfInterestFilter = .excludingAll
        options.size = mapView.frame.size == .zero ? CGSize(width: 300, height: 300) : mapView.frame.size
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            guard let snapshot = snapshot else { return }
            UIGraphicsBeginImageContextWithOptions(options.size, true, 0)
            snapshot.image.draw(at: .zero)
            // Draw polyline
            for segment in segments{
                if segment.coordinates.count > 1 {
                    let path = UIBezierPath()
                    let firstPoint = snapshot.point(for: segment.coordinates[0].toCL())
                    path.move(to: firstPoint)
                    for coord in segment.coordinates.dropFirst() {
                        let point = snapshot.point(for: coord.toCL())
                        path.addLine(to: point)
                    }
                    UIColor.white.setStroke()
                    path.lineWidth = 8
                    path.stroke()
                    UIColor.blue.setStroke()
                    path.lineWidth = 4
                    path.stroke()
                }
            }
            // Draw pins
            for point in points {
                let pointInSnapshot = snapshot.point(for: point.coordinate.toCL())
                guard let pinImage = UIImage(systemName: "mappin")?.withTintColor(.red, renderingMode: .alwaysOriginal) else {
                    return
                }
                pinImage.draw(at: CGPoint(x: pointInSnapshot.x - pinImage.size.width/2, y: pointInSnapshot.y - pinImage.size.height))
                // キャプション
                let title = point.title ?? ""
                let time = point.time?.text ?? ""
                let caption = (title + time)  as NSString? ?? ""
                let font = UIFont.boldSystemFont(ofSize: 12)
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
                let textSize = caption.size(withAttributes: textAttributes)
                let textPadding: CGFloat = 4
                var backgroundRect: CGRect
                if point != points.last {
                    backgroundRect = CGRect(
                        x: pointInSnapshot.x - textSize.width / 2 - textPadding,
                        y: pointInSnapshot.y + 4,
                        width: textSize.width + textPadding * 2,
                        height: textSize.height + textPadding * 2
                    )
                } else{
                    backgroundRect = CGRect(
                        x: pointInSnapshot.x - textSize.width / 2 - textPadding,
                        y: pointInSnapshot.y - pinImage.size.height - ( textSize.height + textPadding * 2 ) - 4,
                        width: textSize.width + textPadding * 2,
                        height: textSize.height + textPadding * 2
                    )
                }

                // 白背景
                let context = UIGraphicsGetCurrentContext()
                context?.setFillColor(UIColor.white.cgColor)
                context?.fill(backgroundRect)

                // 黒文字（中央揃え）
                let textOrigin = CGPoint(
                    x: backgroundRect.origin.x + textPadding,
                    y: backgroundRect.origin.y + textPadding
                )
                caption.draw(at: textOrigin, withAttributes: textAttributes)
            }

            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            DispatchQueue.main.async {
                self.mapSnapshot = image
            }
       }
   }
}
