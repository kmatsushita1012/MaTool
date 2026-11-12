import Dependencies
import Testing
@testable import iOSApp

struct GetSceneSelectionUseCaseTests {
    @Test("保存された祭典と地区の両方のIDを返す")
    func returnsPersistedIdentifiers() {
        let spy = DefaultUserDefaultsSpy(festivalId: "festival", districtId: "district")
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[UserDefaltsManagerKey.self] = spy
        } operation: {
            GetSceneSelectionUseCase()
        }

        #expect(useCase().festivalId == "festival")
        #expect(useCase().districtId == "district")
    }

    @Test("保存されていない選択情報はnilのまま返す")
    func preservesMissingIdentifiers() {
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[UserDefaltsManagerKey.self] = DefaultUserDefaultsSpy()
        } operation: {
            GetSceneSelectionUseCase()
        }

        #expect(useCase() == SceneSelection(festivalId: nil, districtId: nil))
    }
}
