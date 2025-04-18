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
        var date: SimpleDate
        var start: SimpleTime
        var end: SimpleTime
        
        var span: Span {
            let start = DateTime(date: date, time: self.start)
            let end = DateTime(date: date, time: self.end)
            return Span(id: id,start: start, end: end)
        }
        
        init(_ span :Span){
            id = span.id
            date = span.start.date
            start = span.start.time
            end = span.end.time
        }
        
        init(){
            id = UUID().uuidString
            date = SimpleDate.today
            start = SimpleTime(hour: 9, minute: 0)
            end = SimpleTime(hour: 12, minute: 0)
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
