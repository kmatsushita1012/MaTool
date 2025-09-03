//
//  Fragments.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/09.
//

import UIKit
import MapKit
import SwiftUI

class PointAnnotation: MKPointAnnotation {
    enum TitleType {
        case simple
        case time(Int)
    }
    let point: Point
    
    init(_ point: Point,type: TitleType) {
        self.point = point
        super.init()
        self.coordinate = point.coordinate.toCL()
        switch type {
        case .simple:
            self.title = point.title
        case .time(let index):
            let hasSuffix = (point.title?.isEmpty == false) || (point.time != nil)
            let titleText = [point.title, point.time?.text]
                .compactMap { $0 }
                .joined(separator: " ")

            self.title = hasSuffix ? "\(index+1): \(titleText)" : "\(index+1)"
        }
        
    }
}

extension PointAnnotation{
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? PointAnnotation else { return false }
        return self.point == other.point
    }
}

final class PointAnnotationView: MKMarkerAnnotationView {
    override var annotation: MKAnnotation? {
        willSet {
            guard let _ = newValue as? PointAnnotation else { return }
            displayPriority = .required
            if #available(iOS 11.0, *) {
                clusteringIdentifier = nil
            }
            markerTintColor = UIColor(.annotation)
            zPriority = .defaultUnselected
        }
    }
}

extension PointAnnotationView {
    static let identifier = "PointAnnotationView"

    static func view(for mapView: MKMapView, annotation: PointAnnotation) -> MKAnnotationView {
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? PointAnnotationView

        if annotationView == nil {
            annotationView = PointAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        } else {
            annotationView?.annotation = annotation
        }

        return annotationView!
    }
}

class FloatAnnotation: MKPointAnnotation {
}

final class FloatCurrentAnnotation: FloatAnnotation {
    let location: LocationInfo
    
    init(location: LocationInfo) {
        self.location = location
        super.init()
        self.title = location.districtName
        self.coordinate = location.coordinate.toCL()
    }
}

final class FloatReplayAnnotation: FloatAnnotation {
    init(name: String, coordinate: Coordinate) {
        super.init()
        self.title = name
        self.coordinate = coordinate.toCL()
    }
    
    func update(coordinate: Coordinate) {
        self.coordinate = coordinate.toCL()
    }
}

final class FloatAnnotationView: MKMarkerAnnotationView {
    static let identifier = "FloatAnnotationView"
    override var annotation: MKAnnotation? {
        willSet {
            setUp()
        }
    }
    
    init(_ annotation: FloatAnnotation?){
        super.init(annotation: annotation, reuseIdentifier: Self.identifier)
        setUp()
    }
    
    @MainActor required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setUp() {
        guard let baseImage = UIImage(systemName: "circle.circle.fill") else { return }
        let tintedImage = baseImage.withTintColor(.red, renderingMode: .alwaysOriginal)
        
        let shadowColor = UIColor.white.cgColor
        let shadowOffset = CGSize(width: 0, height: 2)
        let shadowRadius: CGFloat = 4

        // サイズ拡大
        let scale: CGFloat = 2
        let newSize = CGSize(width: tintedImage.size.width * scale,
                             height: tintedImage.size.height * scale)
        // レンダリング
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let renderedImage = renderer.image { context in
            let cgContext = context.cgContext

            cgContext.setShadow(
                offset: shadowOffset,
                blur: shadowRadius,
                color: shadowColor
            )
            cgContext.scaleBy(x: 1, y: 1)
            tintedImage.draw(in: CGRect(origin: .zero, size: newSize))
        }

        image = renderedImage
        displayPriority = .required
        zPriority = .max
        canShowCallout = false
        markerTintColor = .clear
        glyphTintColor = .clear
        glyphImage = nil
    }
}

extension FloatAnnotationView {
    static func view(for mapView: MKMapView, annotation: FloatAnnotation) -> MKAnnotationView {
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? FloatAnnotationView

        if annotationView == nil {
            annotationView = FloatAnnotationView(annotation)
        } else {
            annotationView?.annotation = annotation
        }

        return annotationView!
    }
}

class SegmentPolyline: MKPolyline {
    var segment: Segment? = nil
}

final class PathPolyline: MKPolyline {
    convenience init(from start: Point, to end: Point) {
        let coordinates = [start.coordinate.toCL(), end.coordinate.toCL()]
        self.init(coordinates: coordinates, count: coordinates.count)
    }
    
    func renderer() -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: self)
        renderer.strokeColor = .systemBlue
        renderer.lineWidth = 4
        renderer.alpha = 0.8
        return renderer
    }
}


fileprivate extension UIImage {
    /// 元の画像に指定されたシャドウを描画して imageWithShadow を返す
    func imageWithShadow(
        shadowColor: UIColor = .white,
        shadowOffset: CGSize = CGSize(width: 0, height: 2),
        shadowBlur: CGFloat = 4
    ) -> UIImage? {
        let scale = self.scale
        let size = CGSize(width: self.size.width * scale, height: self.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let cgContext = context.cgContext

            cgContext.setShadow(
                offset: shadowOffset,
                blur: shadowBlur,
                color: shadowColor.cgColor
            )

            // ピクセルスケールを反映した描画
            cgContext.scaleBy(x: scale, y: scale)
            self.draw(at: .zero)
        }
    }
}
