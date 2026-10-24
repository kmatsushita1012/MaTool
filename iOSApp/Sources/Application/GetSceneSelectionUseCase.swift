import ComposableArchitecture
import Dependencies

protocol GetSceneSelectionUseCaseProtocol: Sendable {
    func callAsFunction() -> SceneSelection
}

struct GetSceneSelectionUseCase: GetSceneSelectionUseCaseProtocol {
    @Dependency(UserDefaltsManagerKey.self) private var userDefaults

    func callAsFunction() -> SceneSelection {
        SceneSelection(
            festivalId: userDefaults.defaultFestivalId,
            districtId: userDefaults.defaultDistrictId
        )
    }
}

enum GetSceneSelectionUseCaseKey: DependencyKey {
    static let liveValue: any GetSceneSelectionUseCaseProtocol = GetSceneSelectionUseCase()
}
