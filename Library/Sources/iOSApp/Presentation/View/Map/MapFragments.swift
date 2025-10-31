//
//  Fragments.swift
//  MaTool
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

final class FloatAnnotationView: MKAnnotationView {
    static let identifier = "FloatAnnotationView"

    override var annotation: MKAnnotation? {
        didSet {
            configure()
        }
    }
    
    init(_ annotation: FloatAnnotation?){
        super.init(annotation: annotation, reuseIdentifier: Self.identifier)
        configure()
    }
    
    @MainActor required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configure() {
        guard let annotation else { return }
        guard let title = annotation.title else { return }
        
        // ベース画像（赤い丸）
        guard let baseImage = UIImage(systemName: "circle.circle.fill") else { return }
        let tintedImage = baseImage.withTintColor(.red, renderingMode: .alwaysOriginal)

        // スケールアップ
        let scale: CGFloat = 2
        let baseSize = CGSize(width: tintedImage.size.width * scale,
                              height: tintedImage.size.height * scale)
        
        //影
        let shadowColor = UIColor.white.cgColor
        let shadowOffset = CGSize(width: 0, height: 2)
        let shadowRadius: CGFloat = 4

        // テキスト
        let outlineFontSize = 14
        let textColor = UIColor.black
        let outlineColor = UIColor.white
        
        let font = UIFont.systemFont(ofSize: CGFloat(outlineFontSize), weight: .bold)
        let outlineFont = UIFont.systemFont(ofSize: font.pointSize,
                                            weight: .black)
        // テキストサイズを計算
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (title! as NSString).size(withAttributes: attributes)

        // 全体サイズ（画像の下にテキスト分スペースを確保）
        let newSize = CGSize(
            width: max(baseSize.width, textSize.width),
            height: baseSize.height + textSize.height + 4
        )
        
        // テキストの位置
        let textCenter = CGPoint(
            x: newSize.width / 2,
            y: baseSize.height + textSize.height / 2 + 2
        )
        let textOrigin = CGPoint(
            x: textCenter.x - textSize.width / 2,
            y: textCenter.y - textSize.height / 2
        )

        // レンダリング
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let renderedImage = renderer.image { context in
            //影
            let cgContext = context.cgContext
            cgContext.setShadow(offset: shadowOffset,
                                    blur: shadowRadius,
                                    color: shadowColor)
            // ベース画像を上に描画
            let baseOrigin = CGPoint(
                x: (newSize.width - baseSize.width) / 2,
                y: 0
            )
            tintedImage.draw(in: CGRect(origin: baseOrigin, size: baseSize))
            
            // 1. アウトライン用（少し大きめフォント、白）
            (title! as NSString).draw(at: textOrigin, withAttributes: [
                .font: outlineFont,
                .foregroundColor: outlineColor
            ])

            // 2. 本体文字（黒）
            (title! as NSString).draw(at: textOrigin, withAttributes: [
                .font: font,
                .foregroundColor: textColor
            ])
        }

        self.image = renderedImage

        // 座標を画像の中心に合わせる
        let offsetY = textSize.height / 2 
        self.centerOffset = CGPoint(x: 0, y: Int(offsetY))
        
        displayPriority = .required
        zPriority = .max
        canShowCallout = false
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
