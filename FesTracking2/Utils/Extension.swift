//
//  Extension.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Combine
import ComposableArchitecture

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
