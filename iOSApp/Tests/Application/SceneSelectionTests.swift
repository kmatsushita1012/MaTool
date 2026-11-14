import Shared
import Testing
@testable import iOSApp

struct SceneSelectionTests {
    @Test("選択結果は同じ値どうしを等価として扱う")
    func selectionIsValueBased() {
        let first = SceneSelection(festivalId: "festival", districtId: "district")
        let equal = SceneSelection(festivalId: "festival", districtId: "district")
        let changed = SceneSelection(festivalId: "festival", districtId: nil)

        #expect(first == equal)
        #expect(first != changed)
    }

    @Test("祭典選択結果は同じロール同士が等価で、変更と維持は区別される")
    func festivalSelectionResultsDistinguishTransitions() {
        #expect(FestivalSelectionResult.unchanged == .unchanged)
        #expect(FestivalSelectionResult.changed(.guest) == .changed(.guest))
        #expect(FestivalSelectionResult.changed(.district("district")) != .unchanged)
        #expect(FestivalSelectionResult.changed(.district("district")) !=
            .changed(.headquarter("festival")))
    }
    @Test("祭典のみ・地区のみ・未選択をそれぞれ独立して保持する")
    func selectionPreservesPartialIdentifiers() {
        let festivalOnly = SceneSelection(festivalId: "festival", districtId: nil)
        let districtOnly = SceneSelection(festivalId: nil, districtId: "district")
        let empty = SceneSelection(festivalId: nil, districtId: nil)

        #expect(festivalOnly.festivalId == "festival")
        #expect(festivalOnly.districtId == nil)
        #expect(districtOnly.festivalId == nil)
        #expect(districtOnly.districtId == "district")
        #expect(empty.festivalId == nil)
        #expect(empty.districtId == nil)
        #expect(festivalOnly != districtOnly)
        #expect(districtOnly != empty)
    }

}
