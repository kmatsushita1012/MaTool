//
//  Point+Validation.swift
//  matool-shared
//
//  Created by 松下和也 on 2026/01/08.
//

import Foundation

public extension Point{
    enum Error: LocalizedError {
        case multiplePointRelations(Point)
        case missingTimeForCheckpoint(Point)
        case missingTimeForAnchor(Point)
        case multipleStartAnchors
        case multipleEndAnchors
        case startAnchorNotFirst
        case endAnchorNotLast
        case nonMonotonicTime
        case unknown(String)
        
        public var errorDescription: String? {
            switch self {
            case .multiplePointRelations(let point):
                "\(point.index+1)番目: 一箇所に複数のイベントが設定されています"
            case .missingTimeForCheckpoint(let point):
                "\(point.index+1)番目: 時刻が設定されていません"
            case .missingTimeForAnchor(let point):
                "\(point.index+1)番目: 時刻が設定されていません"
            case .multipleStartAnchors:
                "複数の出発地点が設定されています"
            case .multipleEndAnchors:
                "複数の到着地点が設定されています"
            case .startAnchorNotFirst:
                "出発地点が先頭に設定されていません"
            case .endAnchorNotLast:
                "到着地点が最後に設定されていません"
            case .nonMonotonicTime:
                "時刻の順序が不適切です"
            case .unknown(let message):
                message
            }
        }
    }
}

public extension Point {
    func validate() throws {
        let relations = [
            checkpointId != nil,
            performanceId != nil,
            anchor != nil
        ].filter { $0 }.count

        if relations > 1 {
            throw Point.Error.multiplePointRelations(self)
        }

        if checkpointId != nil && time == nil {
            throw Point.Error.missingTimeForCheckpoint(self)
        }

        if anchor != nil && time == nil {
            throw Point.Error.missingTimeForAnchor(self)
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
            throw Point.Error.multipleStartAnchors
        }

        if endAnchors.count > 1 {
            throw Point.Error.multipleEndAnchors
        }

        // ③ 位置制約
        if startAnchors.count == 1,
           first?.anchor != .start {
            throw Point.Error.startAnchorNotFirst
        }

        if endAnchors.count == 1,
           last?.anchor != .end {
            throw Point.Error.endAnchorNotLast
        }

        // ④ 時刻の単調増加
        let times = compactMap(\.time)
        if times != times.sorted() {
            throw Point.Error.nonMonotonicTime
        }
        
        return
    }
}

extension Point: Comparable {
    public static func < (lhs: Point, rhs: Point) -> Bool {
        return lhs.index < rhs.index
    }
}

public extension Array where Element == Point {
    func reindexed() -> [Point] {
        enumerated().map { offset, point in
            var copy = point
            copy.index = offset
            return copy
        }
    }
}
