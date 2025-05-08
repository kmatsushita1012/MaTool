////
////  Sample.swift
////  FesTracking2
////
////  Created by 松下和也 on 2025/05/08.
////
//
//import SwiftUI
//import MapKit
//import PDFKit
//
//struct MapPinPolylineView: UIViewRepresentable {
//    let pins: [CLLocationCoordinate2D]
//    let polyline: [CLLocationCoordinate2D]
//    @Binding var mapSnapshot: UIImage?
//
//    func makeUIView(context: Context) -> MKMapView {
//        let mapView = MKMapView()
//        mapView.delegate = context.coordinator
//
//        // Add pins
//        for coord in pins {
//            let annotation = MKPointAnnotation()
//            annotation.coordinate = coord
//            mapView.addAnnotation(annotation)
//        }
//
//        // Add polyline
//        let polylineOverlay = MKPolyline(coordinates: polyline, count: polyline.count)
//        mapView.addOverlay(polylineOverlay)
//
//        // Set region
//        if let first = pins.first {
//            let region = MKCoordinateRegion(center: first, latitudinalMeters: 1000, longitudinalMeters: 1000)
//            mapView.setRegion(region, animated: false)
//        }
//
//        // Take snapshot after a short delay
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//            takeSnapshot(mapView: mapView)
//        }
//
//        return mapView
//    }
//
//    func updateUIView(_ uiView: MKMapView, context: Context) {
//        // No-op
//    }
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//
//    class Coordinator: NSObject, MKMapViewDelegate {
//        var parent: MapPinPolylineView
//
//        init(_ parent: MapPinPolylineView) {
//            self.parent = parent
//        }
//
//        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
//            if let polyline = overlay as? MKPolyline {
//                let renderer = MKPolylineRenderer(polyline: polyline)
//                renderer.strokeColor = .blue
//                renderer.lineWidth = 4
//                return renderer
//            }
//            return MKOverlayRenderer(overlay: overlay)
//        }
//    }
//
//    private func takeSnapshot(mapView: MKMapView) {
//        let options = MKMapSnapshotter.Options()
//        options.region = mapView.region
//        options.size = mapView.frame.size == .zero ? CGSize(width: 300, height: 300) : mapView.frame.size
//
//        let snapshotter = MKMapSnapshotter(options: options)
//        snapshotter.start { snapshot, error in
//            guard let snapshot = snapshot else { return }
//            UIGraphicsBeginImageContextWithOptions(options.size, true, 0)
//            snapshot.image.draw(at: .zero)
//
//            // Draw pins
//            for coord in pins {
//                let point = snapshot.point(for: coord)
//                let pinImage = UIImage(systemName: "mappin")?.withTintColor(.red, renderingMode: .alwaysOriginal)
//                pinImage?.draw(at: CGPoint(x: point.x - 10, y: point.y - 30))
//            }
//
//            // Draw polyline
//            if polyline.count > 1 {
//                let path = UIBezierPath()
//                let firstPoint = snapshot.point(for: polyline[0])
//                path.move(to: firstPoint)
//                for coord in polyline.dropFirst() {
//                    let point = snapshot.point(for: coord)
//                    path.addLine(to: point)
//                }
//                UIColor.blue.setStroke()
//                path.lineWidth = 4
//                path.stroke()
//            }
//
//            let image = UIGraphicsGetImageFromCurrentImageContext()
//            UIGraphicsEndImageContext()
//            DispatchQueue.main.async {
//                self.mapSnapshot = image
//            }
//        }
//    }
//}
//
//struct PDFShareView: View {
//    let pins: [CLLocationCoordinate2D]
//    let polyline: [CLLocationCoordinate2D]
//    @State private var mapSnapshot: UIImage? = nil
//    @State private var showShareSheet = false
//    @State private var pdfURL: URL?
//
//    var body: some View {
//        VStack {
//            MapPinPolylineView(pins: pins, polyline: polyline, mapSnapshot: $mapSnapshot)
//                .frame(height: 300)
//                .cornerRadius(12)
//                .padding()
//
//            Button("PDFで共有") {
//                if let image = mapSnapshot {
//                    pdfURL = createPDF(with: image)
//                    showShareSheet = true
//                }
//            }
//            .disabled(mapSnapshot == nil)
//            .padding()
//        }
//        .sheet(isPresented: $showShareSheet) {
//            if let url = pdfURL {
//                ShareSheet(activityItems: [url])
//            }
//        }
//    }
//
//    func createPDF(with image: UIImage) -> URL? {
//        let pdfData = NSMutableData()
//        let pdfRect = CGRect(origin: .zero, size: image.size)
//        UIGraphicsBeginPDFContextToData(pdfData, pdfRect, nil)
//        UIGraphicsBeginPDFPage()
//        image.draw(in: pdfRect)
//        UIGraphicsEndPDFContext()
//
//        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("map.pdf")
//        do {
//            try pdfData.write(to: tempURL, options: .atomic)
//            return tempURL
//        } catch {
//            return nil
//        }
//    }
//}
//
//struct ShareSheet: UIViewControllerRepresentable {
//    let activityItems: [Any]
//    func makeUIViewController(context: Context) -> UIActivityViewController {
//        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
//    }
//    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
//}
//
//// サンプルデータでプレビュー
//struct PDFShareView_Previews: PreviewProvider {
//    static var pins = [
//        CLLocationCoordinate2D(latitude: 34.775, longitude: 137.998),
//        CLLocationCoordinate2D(latitude: 34.776, longitude: 137.999)
//    ]
//    static var polyline = [
//        CLLocationCoordinate2D(latitude: 34.775, longitude: 137.998),
//        CLLocationCoordinate2D(latitude: 34.776, longitude: 137.999),
//        CLLocationCoordinate2D(latitude: 34.777, longitude: 138.000)
//    ]
//    static var previews: some View {
//        PDFShareView(pins: pins, polyline: polyline)
//    }
//}
