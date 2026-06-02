//
//  DistrictDashboardView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct DistrictDashboardView: View{
    @SwiftUI.Bindable var store: StoreOf<DistrictDashboardFeature>
    
    var body: some View {
        content
            .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)){ destination in
                switch destination.case {
                case .edit(let store):
                    DistrictEditView(store: store)
                case .location(let store):
                    LocationTrackingView(store: store)
                case .route(let store):
                    RouteEditView(store: store)
                case .changePassword(let store):
                    ChangePasswordView(store: store)
                case .updateEmail(let store):
                    UpdateEmailView(store: store)
                }
            }
            .sheet(item: $store.url) { url in
                ShareSheet(item: url)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .loadingOverlay(store.isLoading)
        
    }
    
    @ViewBuilder
    var content: some View {
        List {
            Section {
                NavigationItemView(
                    title: "地区情報",
                    iconName: "info.circle" ,
                    onTap: {
                        store.send(.onEdit)
                    })
                NavigationItemView(
                    title: "位置情報配信",
                    iconName: "mappin.and.ellipse",
                    onTap: {
                        store.send(.onLocation)
                    }
                )
            }
            Section(header: Text("行動")){
                ForEach(store.routes) { pair in
                    RouteSlotView(
                        pair,
                        onTap: { store.send(.onRouteEdit(pair)) }
                    )
                }
            }
            Section(header: Text("ルート出力")) {
                Button(action: {
                    store.send(.submissionExportTapped)
                }) {
                    Text("提出資料出力")
                }
                Button(action: {
                    store.send(.tableExportTapped)
                }) {
                    Text("行動表出力")
                }
            }
            Section {
                Button(action: {
                    store.send(.changePasswordTapped)
                }) {
                    Text("パスワード変更")
                }
                Button(action: {
                    store.send(.updateEmailTapped)
                }) {
                    Text("メールアドレス変更")
                }
            }
            Section {
                Button(action: {
                    store.send(.signOutTapped)
                }) {
                    Text("ログアウト")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(
            store.district.name
        )
        .navigationBarTitleDisplayMode(.large)
    }
}
