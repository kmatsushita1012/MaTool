//
//  Extensions.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/08.
//
import MapKit
import Foundation
import SwiftUI
import Shared


func makeRegion(_ coordinates:[Coordinate], ratio :Double = 1.1) -> MKCoordinateRegion {
    let minLat = coordinates.map { $0.latitude }.min() ?? 0
    let maxLat = coordinates.map { $0.latitude }.max() ?? 0
    let minLon = coordinates.map { $0.longitude }.min() ?? 0
    let maxLon = coordinates.map { $0.longitude }.max() ?? 0

    let center = CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2
    )
    let latitudeDelta = (maxLat - minLat) * ratio
    let longitudeDelta = (maxLon - minLon) * ratio
    let span = MKCoordinateSpan(
        latitudeDelta: spanDelta > latitudeDelta ? spanDelta: latitudeDelta,
        longitudeDelta: spanDelta > longitudeDelta ? spanDelta: longitudeDelta
    )

    return MKCoordinateRegion(center: center, span: span)
}

func makeRegion(origin: Coordinate, spanDelta: CLLocationDegrees) -> MKCoordinateRegion {
    return MKCoordinateRegion(
        center: origin.toCL(),
        span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
    )
}

func makeRegion(route: Route?, location: FloatLocationGetDTO?, origin: Coordinate, spanDelta: CLLocationDegrees) -> MKCoordinateRegion {
    if let location {
        return makeRegion(origin: location.coordinate, spanDelta: spanDelta)
    } else if let route {
        return makeRegion(route.points.map { $0.coordinate })
    } else {
        return makeRegion(origin: origin, spanDelta: spanDelta)
    }
}

func makeRegion(locations: [FloatLocationGetDTO], origin: Coordinate) -> MKCoordinateRegion {
    if !locations.isEmpty {
        return makeRegion(locations.map { $0.coordinate })
    } else {
        return makeRegion(origin: origin, spanDelta: spanDelta)
    }
}

extension View {
    func stroke(color: Color, width: CGFloat = 1) -> some View {
        modifier(StrokeModifier(strokeSize: width, strokeColor: color))
    }
}

struct StrokeModifier: ViewModifier {
    private let id = UUID()
    var strokeSize: CGFloat = 1
    var strokeColor: Color = .blue

    func body(content: Content) -> some View {
        if strokeSize > 0 {
            appliedStrokeBackground(content: content)
        } else {
            content
        }
    }

    private func appliedStrokeBackground(content: Content) -> some View {
        content
            .padding(strokeSize*2)
            .background(
                Rectangle()
                    .foregroundColor(strokeColor)
                    .mask(alignment: .center) {
                        mask(content: content)
                    }
            )
    }

    func mask(content: Content) -> some View {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: 0.01))
            if let resolvedView = context.resolveSymbol(id: id) {
                context.draw(resolvedView, at: .init(x: size.width/2, y: size.height/2))
            }
        } symbols: {
            content
                .tag(id)
                .blur(radius: strokeSize)
        }
    }
}

extension Color {
    static let map = Color(red: 255/255, green: 183/255, blue: 167/255)
    static let info = Color(red: 255 / 255, green: 140 / 255, blue: 89 / 255)
    static let onboarding = Color(red: 179 / 255, green: 38 / 255, blue: 30 / 255)
    static let annotation = Color(red: 255/255, green: 108/255, blue: 76/255)
}

enum Mode: Equatable {
    case update
    case create
}

extension Mode {
    var title: String {
        switch self {
        case .update: return "更新"
        case .create: return "新規作成"
        }
    }
}
