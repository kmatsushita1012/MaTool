//
//  Extension.swift
//  MaTool
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
    
    func prioritizing<Value: Equatable>(
        by keyPath: KeyPath<Element, Value>,
        match value: Value
    ) -> [Element] {
        guard let matchedIndex = firstIndex(where: { $0[keyPath: keyPath] == value }) else {
            return self // 該当IDがなければそのまま返す
        }
        var reordered = self
        let matched = reordered.remove(at: matchedIndex)
        reordered.insert(matched, at: 0)
        return reordered
    }
}

extension Array where Element: Equatable {
    mutating func removeAll(of element: Element){
        removeAll(where: { $0 == element })
    }
}

extension Array {
    mutating func insert(_ value: Element, before index: Int) {
        let i = Swift.max(0, Swift.min(index, count))
        insert(value, at: i)
    }

    mutating func insert(_ value: Element, after index: Int) {
        let i = Swift.max(0, Swift.min(index + 1, count))
        insert(value, at: i)
    }
}

// MARK: - Sequence Extension

extension Sequence {
    func first<Value: Equatable>(where keyPath: KeyPath<Element, Value>, equals value: Value) -> Element? {
        first { $0[keyPath: keyPath] == value }
    }

    func filter<Value: Equatable>(where keyPath: KeyPath<Element, Value>, equals value: Value) -> [Element] {
        filter { $0[keyPath: keyPath] == value }
    }

    func contains<Value: Equatable>(where keyPath: KeyPath<Element, Value>, equals value: Value) -> Bool {
        contains { $0[keyPath: keyPath] == value }
    }

    func map<Value>(keyPath: KeyPath<Element, Value>) -> [Value] {
        map { $0[keyPath: keyPath] }
    }
}

extension Collection {
    func first<Value: Equatable>(where keyPath: KeyPath<Element, Value>, equals value: Value) -> Element? {
        first { $0[keyPath: keyPath] == value }
    }
}

// MARK: - Collection + Identifiable

extension Collection where Element: Identifiable {
    func first(matching id: Element.ID) -> Element? {
        first(where: \.id, equals: id)
    }
}

extension MKCoordinateRegion: @retroactive Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        return lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude &&
               lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
               lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}

extension Result {
    var value: Success? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    var error: Failure? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
    
    func asyncFlatMap<T>(_ transform: @escaping (Success) async -> Result<T, Failure>) async -> Result<T, Failure> {
        switch self {
        case .success(let value):
            return await transform(value)
        case .failure(let error):
            return .failure(error)
        }
    }
}
