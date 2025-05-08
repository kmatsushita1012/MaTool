////
////  AuthPage.swift
////  FesTracking2
////
////  Created by 松下和也 on 2025/04/02.
////
//
//import ComposableArchitecture
//import AWSMobileClient
//
//@Reducer
//struct AuthFeature {
//    @ObservableState
//    struct State: Equatable{
//        var isSignIn: Bool
//        @Presents var loginPage: LoginFeature.State?
//    }
//    
//    enum Action: Equatable{
//        case checkUserState
//        case userStateReceived(Result<UserState?,AWSCognitoError>)
//        case loginButtonTapped
//        case logoutButtonTapped
//        case loginPage(PresentationAction<LoginFeature.Action>)
//    }
//    
//    @Dependency(\.awsCognitoClient) var awsCognitoClient
//    @Dependency(\.userDefaultsClient) var userDefaultsClient
//    
//    var body: some ReducerOf<AuthFeature> {
//        Reduce{ state, action in
//            switch action {
//            case .checkUserState:
//                return .run { send in
//                    let result = await awsCognitoClient.initialize()
//                    await send(.userStateReceived(result))
//                }
//            case .userStateReceived(.success(let userState)):
//                if let userState = userState{
//                    state.isSignIn = (userState == .signedIn)
//                }else{
//                    state.isSignIn = false
//                }
//                return .none
//            case .userStateReceived(.failure(_)):
//                return .none
//            case .loginButtonTapped:
//                state.loginPage = LoginFeature.State()
//                return .none
//            case .logoutButtonTapped:
//                state.isSignIn = false
//                return .run { send in
//                    let _ = await awsCognitoClient.signOut()
//                }
//            case .loginPage(.presented(.responseReceived(.success(_)))):
//                state.isSignIn = true
//                state.loginPage = nil
//                return .none
//            case .loginPage(.presented(.responseReceived(.failure(_)))):
//                state.isSignIn = false
//                state.loginPage = nil
//                return .none
//            default:
//                return .none
//            }
//        }
//        .ifLet(\.$loginPage, action: \.loginPage) {
//            LoginFeature()
//        }
//    }
//}
