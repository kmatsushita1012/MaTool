//
//  AdminDistrictView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

struct AdminDistrictView: View{
    @Bindable var store: StoreOf<AdminDistrictTop>
    
    var body: some View {
        NavigationView {
            Form{
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
                    List(store.routes) { route in
                        AdminRouteItem(
                            text: route.text(format:"m/d T"),
                            onEdit: { store.send(.onRouteEdit(route)) },
                            onExport:{ store.send(.onRouteExport(route)) }
                        )
                    }
                    Button(action: {
                        store.send(.onRouteAdd)
                    }) {
                        Label("追加", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity, alignment: .center)
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        store.send(.homeTapped)
                    }) {
                        Image(systemName: "house")
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 8)
                }
            }
            .navigationDestination(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) { store in
               AdminDistrictEditView(store: store)
                    .interactiveDismissDisabled(true)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.location, action: \.destination.location)) { store in
                LocationAdminView(store: store)
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.route, action: \.destination.route)) { store in
                AdminRouteInfoView(store: store)
                    .interactiveDismissDisabled(true)
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.export, action: \.destination.export)) { store in
                AdminRouteExportView(store: store)
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(
                item: $store.scope(state: \.destination?.changePassword, action: \.destination.changePassword)
            ) { store in
                ChangePasswordStoreView(store: store)
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(
                item: $store.scope(state: \.destination?.updateEmail, action: \.destination.updateEmail)
            ) { store in
                UpdateEmailStoreView(store: store)
                    .navigationBarBackButtonHidden(true)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .loadingOverlay(store.isLoading)
        }
    }
}
