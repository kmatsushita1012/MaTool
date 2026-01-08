//
//  Error.swift
//  matool-shared
//
//  Created by 松下和也 on 2026/01/08.
//

public enum DomainError: Error, Equatable {
    // Point 単体
    case multiplePointRelations(pointId: String)
    case missingTimeForCheckpoint(pointId: String)
    case missingTimeForAnchor(pointId: String)

    // Point 配列
    case multipleStartAnchors
    case multipleEndAnchors
    case startAnchorNotFirst
    case endAnchorNotLast
    case nonMonotonicTime
}
