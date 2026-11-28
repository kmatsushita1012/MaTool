#if DEBUG
import ComposableArchitecture
import Dependencies

@Reducer
struct DebugMenuFeature {
    @ObservableState
    struct State: Equatable {
        var apiEnvironment: DebugAPIEnvironment
        var customStage: String

        init() {
            @Dependency(UserDefaltsManagerKey.self) var userDefaultsManager
            self.apiEnvironment = userDefaultsManager.debugAPIEnvironment ?? .dev
            self.customStage = userDefaultsManager.debugAPICustomStage ?? ""
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case closeTapped
    }

    @Dependency(UserDefaltsManagerKey.self) private var userDefaultsManager
    @Dependency(\.dismiss) private var dismiss

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.apiEnvironment):
                userDefaultsManager.saveDebugAPIEnvironment(state.apiEnvironment)
                return .none
            case .binding(\.customStage):
                userDefaultsManager.saveDebugAPICustomStage(state.customStage)
                return .none
            case .binding:
                return .none
            case .closeTapped:
                return .dismiss
            }
        }
    }
}
#endif
