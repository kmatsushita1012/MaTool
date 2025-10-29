//
//  InformationEdit.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/25.
//

import ComposableArchitecture

@Reducer
struct InformationEdit {
    
    @ObservableState
    struct State: Equatable{
        let title: String
        var item: Information
    }
    
    @CasePathable
    enum Action: Equatable,BindableAction {
        case binding(BindingAction<State>)
        case cancelTapped
        case doneTapped
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<InformationEdit>{
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .cancelTapped:
                return .run { _ in
                    await dismiss()
                }
            case .doneTapped:
                return .none
            }
        }
    }
}
