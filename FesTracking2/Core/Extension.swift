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
import SwiftUICore

struct Stack<Element: Equatable>: Equatable{
    private var elements: [Element] = []
    
    mutating func push(_ element: Element) {
        elements.append(element)
    }
    
    mutating func pop() -> Element? {
        return elements.popLast()
    }
    
    func peek() -> Element? {
        return elements.last
    }
    
    var isEmpty: Bool {
        return elements.isEmpty
    }
    
    var count: Int {
        return elements.count
    }
    
    mutating func clear() -> Void{
        elements = []
    }
    
    static func == (lhs: Stack<Element>, rhs: Stack<Element>) -> Bool {
        return lhs.elements == rhs.elements
    }
}

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
