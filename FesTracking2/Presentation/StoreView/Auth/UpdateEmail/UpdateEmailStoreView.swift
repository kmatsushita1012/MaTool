//
//  UpdateEmailStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/17.
//

import ComposableArchitecture
import SwiftUI

struct UpdateEmailStoreView: View {
    
    @Bindable var store: StoreOf<UpdateEmail>
    @FocusState private var focusedField: Field?
    
    
    enum Field {
        case email
        case code
    }
    
    var body: some View {
        VStack{
            TitleView(
                imageName: "SettingsBackground",
                titleText: "メールアドレス変更",
                font: .title
            ) {
                switch store.step{
                case .enterEmail:
                    store.send(.enterEmail(.dismissTapped))
                case .enterCode:
                    store.send(.enterCode(.dismissTapped))
                }
            }
            .ignoresSafeArea(edges: .top)
            Spacer()
            switch store.step{
            case .enterEmail:
                enterEmail
            case .enterCode:
                enterCode
            }
            Spacer()
            Spacer()
        }
        .loadingOverlay(store.isLoading)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
    
    @ViewBuilder
    var enterEmail: some View {
        VStack{
            TextField("新しいメールアドレス", text: $store.email)
                .textContentType(.emailAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .email)
                .padding()
            Button("確認コードを送信") {
                store.send(.enterEmail(.okTapped))
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
        }
        
    }
    
    @ViewBuilder
    var enterCode: some View {
        VStack{
            TextField("認証コード（6桁）", text: $store.code)
                .textContentType(.oneTimeCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .code)
                .padding()
            Button("確認") {
                store.send(.enterCode(.okTapped))
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
        }
    }
}
