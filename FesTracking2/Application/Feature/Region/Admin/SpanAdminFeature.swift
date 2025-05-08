//
//  SpanAdminFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture
import Foundation

@Reducer
struct SpanAdminFeature {
    @ObservableState
    struct State: Equatable{
        let id: String
        var date: Date
        var start: Date
        var end: Date
        
        var span: Span {
            return Span(id: id, start: Date.combine(date: date, time: start), end: Date.combine(date: date, time: end))
        }
        
        init(_ span :Span){
            id = span.id
            date = span.start
            start = span.start
            end = span.end
        }
        
        init(){
            id = UUID().uuidString
            let now = Date()
            date = now
            start = Date.theDayAt(date: now, hour: 9, minute: 0, second: 0)
            end = Date.theDayAt(date: now, hour: 12, minute: 0, second: 0)
        }
    }
    @CasePathable
    enum Action:BindableAction {
        case binding(BindingAction<State>)
        case doneButtonTapped
        case cancelButtonTapped
    }
    
    var body: some ReducerOf<SpanAdminFeature>{
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .doneButtonTapped:
                return .none
            case .cancelButtonTapped:
                return .none
            }
        }
    }
}
