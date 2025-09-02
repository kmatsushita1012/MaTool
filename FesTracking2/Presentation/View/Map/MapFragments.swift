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

class FloatAnnotationProtocol: MKPointAnnotation {}

final class FloatAnnotation: FloatAnnotationProtocol {
    let location: LocationInfo
    
    init(location: LocationInfo) {
        self.location = location
        super.init()
        self.title = location.districtName
    }
}

final class FloatReplayAnnotation: FloatAnnotationProtocol {
    
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
            canShowCallout = false
            guard let baseImage = UIImage(systemName: "circle.circle.fill") else { return }

            // サイズ拡大
            let scale: CGFloat = 2
            let newSize = CGSize(width: baseImage.size.width * scale,
                                 height: baseImage.size.height * scale)

            let imageView = UIImageView(image: baseImage)
            imageView.bounds = CGRect(origin: .zero, size: newSize)
            imageView.backgroundColor = .clear
            imageView.tintColor = .red
            
            imageView.layer.shadowColor = UIColor.white.cgColor
            imageView.layer.shadowOpacity = 0.8
            imageView.layer.shadowOffset = CGSize(width: 0, height: 2)
            imageView.layer.shadowRadius = 4
            imageView.layer.masksToBounds = false
            imageView.layer.shadowPath = UIBezierPath(ovalIn: imageView.bounds).cgPath

            // レンダリング
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let renderedImage = renderer.image { _ in
                imageView.drawHierarchy(in: CGRect(origin: .zero, size: newSize), afterScreenUpdates: true)
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
}

extension FloatAnnotationView {
    static func view(for mapView: MKMapView, annotation: FloatAnnotationProtocol) -> MKAnnotationView {
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? FloatAnnotationView

        if annotationView == nil {
            annotationView = FloatAnnotationView(annotation: annotation, reuseIdentifier: identifier)
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


