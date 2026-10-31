import Shared
import Testing
@testable import iOSApp

struct RoutePointInsertionTests {
    @Test("最後のPointの後は末尾indexへの挿入操作に切り替える")
    func 最後のPointの後は末尾indexへの挿入操作に切り替える() {
        var insertion = RoutePointInsertion(points: makePoints())

        let didBegin = insertion.begin(afterPointAt: 1)
        #expect(didBegin)
        #expect(insertion.operation == .insert(2))
    }

    @Test("存在しないPointの挿入位置は返さない")
    func 存在しないPointの挿入位置は返さない() {
        var insertion = RoutePointInsertion(points: makePoints())

        let didBeginAtNegativeIndex = insertion.begin(afterPointAt: -1)
        let didBeginAfterLastIndex = insertion.begin(afterPointAt: insertion.points.count)
        #expect(!didBeginAtNegativeIndex)
        #expect(!didBeginAfterLastIndex)
        #expect(insertion.operation == .add)
        var emptyInsertion = RoutePointInsertion(points: [])
        let didBeginWithNoPoints = emptyInsertion.begin(afterPointAt: 0)
        #expect(!didBeginWithNoPoints)
    }

    @Test("最後のPointの後へ挿入すると配列末尾に追加して追加モードへ戻る")
    func 最後のPointの後へ挿入すると配列末尾に追加して追加モードへ戻る() {
        var insertion = RoutePointInsertion(points: makePoints())
        let inserted = Point(id: "inserted", routeId: "route", coordinate: Coordinate(latitude: 2, longitude: 2))

        let didBegin = insertion.begin(afterPointAt: 1)
        #expect(didBegin)
        let didInsert = insertion.insert(inserted)

        #expect(didInsert)
        #expect(insertion.points.map(\.id) == ["first", "last", "inserted"])
        #expect(insertion.operation == .add)
    }

    @Test("配列末尾を越えるindexへの挿入は拒否する")
    func 配列末尾を越えるindexへの挿入は拒否する() {
        var insertion = RoutePointInsertion(points: makePoints(), operation: .insert(3))
        let inserted = Point(id: "inserted", routeId: "route", coordinate: Coordinate(latitude: 1, longitude: 1))

        let didInsert = insertion.insert(inserted)
        #expect(!didInsert)
        #expect(insertion.points.map(\.id) == ["first", "last"])
        #expect(insertion.operation == .insert(3))
    }
}

private func makePoints() -> [Point] {
    [
        Point(id: "first", routeId: "route", coordinate: Coordinate(latitude: 0, longitude: 0)),
        Point(id: "last", routeId: "route", coordinate: Coordinate(latitude: 1, longitude: 1))
    ]
}
