//
//  Point+.swift
//  matool-shared
//
//  Created by 松下和也 on 2026/01/08.
//

public extension Point {
    enum Kind: Entity {
        case checkpoint(Checkpoint.ID)
        case performance(Performance.ID)
        case anchor(Anchor)
        case orphan
    }
    var kind: Kind {
        if let checkpointId {
            return .checkpoint(checkpointId)
        }
        if let performanceId {
            return .performance(performanceId)
        }
        if let anchor {
            return .anchor(anchor)
        }
        return .orphan
    }
}
