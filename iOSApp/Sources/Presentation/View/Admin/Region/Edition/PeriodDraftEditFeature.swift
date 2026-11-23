import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct PeriodDraftEditFeature {
    @ObservableState
    struct State: Equatable {
        let festivalID: Festival.ID
        let isCreateMode: Bool
        var period: Period

        init(festivalID: Festival.ID, isCreateMode: Bool, period: Period) {
            self.festivalID = festivalID
            self.isCreateMode = isCreateMode
            self.period = period
        }

        static func create(_ period: Period, festivalID: Festival.ID) -> Self {
            .init(festivalID: festivalID, isCreateMode: true, period: period)
        }

        static func update(_ period: Period, festivalID: Festival.ID) -> Self {
            .init(festivalID: festivalID, isCreateMode: false, period: period)
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case dateChanged(SimpleDate)
        case saveTapped
        case deleteTapped
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .dateChanged(let date):
                guard let editionID = state.period.editionId else { return .none }
                let period = state.period
                state.period = Period(
                    id: period.id,
                    editionId: editionID,
                    title: period.title,
                    date: date,
                    start: period.start,
                    end: period.end
                )
                return .none
            case .saveTapped, .deleteTapped:
                return .none
            }
        }
    }
}
