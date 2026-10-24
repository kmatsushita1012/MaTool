//
//  PeriodArchivesFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import ComposableArchitecture
import Shared

@Reducer
struct PeriodArchivesFeature {

    @Reducer
    enum Destination {
        case edit(PeriodEditFeature)
    }

    @ObservableState
    struct State: Equatable {
        let festivalId: Festival.ID
        let year: Int
        let periods: [Period]
        @Shared fileprivate var appState: AppState?
        @Presents var destination: Destination.State?

        init(festivalId: Festival.ID, year: Int, periods: [Period], appState: Shared<AppState?>) {
            self.festivalId = festivalId
            self.year = year
            self.periods = periods.sorted()
            self._appState = appState
        }
    }

    @CasePathable
    enum Action: Equatable {
        case periodTapped(Period)
        case destination(PresentationAction<Destination.Action>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .periodTapped(let period):
                state.destination = .edit(.update(period, appState: state.$appState))
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension PeriodArchivesFeature.Destination.State: Equatable {}
extension PeriodArchivesFeature.Destination.Action: Equatable {}
