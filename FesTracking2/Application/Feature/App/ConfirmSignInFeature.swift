//
//  ConfirmSignIn.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/21.
//

import ComposableArchitecture

@Reducer
struct ConfirmSignInFeature {
    @Dependency(\.awsCognitoClient) var awsCognitoClient
    
    @ObservableState
    struct State: Equatable {
        var oldPassword: String = ""
        var newPassword: String = ""
        @Presents var alert: OkAlert.State? = nil
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case submitTapped
        case dismissTapped
        case received(Result<String, AWSCognito.Error>)
    }
    
    var body: some ReducerOf<ConfirmSignInFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .submitTapped:
                return .run { [oldPassword = state.oldPassword, newPassword = state.newPassword ]send in
                    let result = await awsCognitoClient.confirmSignIn(oldPassword,newPassword)
                    await send(.received(result))
                }
            case .dismissTapped:
                return .none
            case .received(.success):
                return .none
            case .received(.failure):
                return .none
            }
            
        }
    }
}
