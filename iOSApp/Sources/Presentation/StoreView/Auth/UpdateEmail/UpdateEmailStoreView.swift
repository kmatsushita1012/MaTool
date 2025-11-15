//
//  UpdateEmailStoreView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/17.
//

import ComposableArchitecture
import SwiftUI
import NavigationSwipeControl

@available(iOS 17.0, *)
struct UpdateEmailStoreView: View {
    
    @SwiftUI.Bindable var store: StoreOf<UpdateEmail>
    @FocusState private var focusedField: Field?
    
    
    enum Field {
        case email
        case code
    }
    
    var body: some View {
        VStack{
            TitleView(
                text: "メールアドレス変更",
                image: "AdminBackground",
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
            case .enterCode(let destination):
                enterCode(destination: destination)
            }
            Spacer()
            Spacer()
        }
        .dismissible(backButton: false, edgeSwipe: false)
        .loadingOverlay(store.isLoading)
        .alert($store.scope(state: \.errorAlert, action: \.errorAlert))
        .alert($store.scope(state: \.completeAlert, action: \.completeAlert))
    }
    
    @ViewBuilder
    var enterEmail: some View {
        VStack{
            TextField("新しいメールアドレス", text: $store.email)
                .textContentType(.emailAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .email)
                .padding()
            Button("変更") {
                store.send(.enterEmail(.okTapped))
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
        }
        
    }
    
    @ViewBuilder
    func enterCode(destination: String) -> some View {
        VStack{
            Text("入力されたメールアドレス　\(destination)　に6桁の確認コードを送信しました。次の画面で入力してください。")
                .foregroundStyle(.gray)
                .padding()
            TextField("認証コード（6桁）", text: $store.code)
                .textContentType(.oneTimeCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .code)
                .padding()
            Button("認証") {
                store.send(.enterCode(.okTapped))
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
        }
        .padding()
    }
}
