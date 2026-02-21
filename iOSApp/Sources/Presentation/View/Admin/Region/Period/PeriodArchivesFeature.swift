//
//  PeriodArchivesFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import ComposableArchitecture
import Shared
import SQLiteData

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
        @FetchAll var periods: [Period]
        @Presents var destination: Destination.State?
        
        init(festivalId: String, year: Int) {
            self.festivalId = festivalId
            self.year = year
            self._periods = FetchAll(Period.where{ $0.festivalId.eq(festivalId) && $0.date.inYear(year) })
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
