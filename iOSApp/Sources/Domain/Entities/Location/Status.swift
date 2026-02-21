//
//  Status.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/20.
//

import Foundation
import Shared

enum Status:Sendable, Equatable, Hashable {
    case update(FloatLocation)
    case delete(Date)
    case loading(Date)
    case locationError(Date)
    case apiError(Date, APIError)
}

extension Status {
extension Status: Identifiable {
    var id: String {
        switch self {
        case .update(let location):
            return location.timestamp.text()
        case .loading(let date):
            return date.text()
        case .locationError(let date):
            return date.text()
        case .apiError(let date, _):
            return date.text()
        case .delete(let date):
            return date.text()
        }
    }
}
