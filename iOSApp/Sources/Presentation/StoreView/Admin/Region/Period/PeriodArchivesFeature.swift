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
        let festivalId: String
        let year: Int
        var periods: [Period]
        @Presents var destination: Destination.State?
    }
    
    @CasePathable
    enum Action: Equatable {
        case periodTapped(Period)
        case destination(PresentationAction<Destination.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .periodTapped(let period):
                state.destination = .edit(.update(period))
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

