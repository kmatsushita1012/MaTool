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
}
