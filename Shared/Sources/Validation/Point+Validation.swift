//
//  Point+Validation.swift
//  matool-shared
//
//  Created by 松下和也 on 2026/01/08.
//

public extension Point {
    func validate() throws {
        let relations = [
            checkpointId != nil,
            performanceId != nil,
            anchor != nil
        ].filter { $0 }.count

        if relations > 1 {
            throw DomainError.multiplePointRelations(pointId: id)
        }

        if checkpointId != nil && time == nil {
            throw DomainError.missingTimeForCheckpoint(pointId: id)
        }

        if anchor != nil && time == nil {
            throw DomainError.missingTimeForAnchor(pointId: id)
        }
    }
}

public extension Array where Element == Point {

    func validate() throws {
        // ① 個体チェック
        try forEach { try $0.validate() }

        // ② Anchor 数
        let anchors = compactMap(\.anchor)

        let startAnchors = anchors.filter { $0 == .start }
        let endAnchors   = anchors.filter { $0 == .end }

        if startAnchors.count > 1 {
            throw DomainError.multipleStartAnchors
        }

        if endAnchors.count > 1 {
            throw DomainError.multipleEndAnchors
        }

        // ③ 位置制約
        if startAnchors.count == 1,
           first?.anchor != .start {
            throw DomainError.startAnchorNotFirst
        }

        if endAnchors.count == 1,
           last?.anchor != .end {
            throw DomainError.endAnchorNotLast
        }

        // ④ 時刻の単調増加
        let times = compactMap(\.time)
        if times != times.sorted() {
            throw DomainError.nonMonotonicTime
        }
    }
}
