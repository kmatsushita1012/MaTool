//
//  Extension.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Combine
import ComposableArchitecture
import MapKit
import SwiftUI

extension Array where Element: Identifiable & Equatable {
    mutating func upsert(_ element: Element) {
        if let index = firstIndex(where: { $0.id == element.id }) {
            self[index] = element
        } else {
            append(element)
        }
    }
}


extension Color {
    static let customLightRed = Color(red: 255/255, green: 183/255, blue: 167/255)
}

extension MKCoordinateRegion: Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        return lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude &&
               lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
               lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}
