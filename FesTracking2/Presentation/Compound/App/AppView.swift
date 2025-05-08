//
//  AppView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/21.
//

import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack{
            VStack(spacing: 16) {
                VStack {
                    Text("地図")
                        .onTapGesture {
                            store.send(.routeTapped)
                        }
                }
                .background(.red)
                HStack(spacing: 16)  {
                    VStack(spacing: 16)  {
                        VStack {
                            Text("紹介")
                                .onTapGesture {
                                    store.send(.infoTapped)
                                }
                        }
                        VStack {
                            Text("編集")
                                .onTapGesture {
                                    store.send(.adminTapped)
                                }
                        }
                    }
                    VStack(spacing: 16)  {
                        VStack {
                            Text("設定")
                                .onTapGesture {
                                    store.send(.settingsTapped)
                                }
                        }
                        VStack {
                            Text("出力")
                                .onTapGesture {
                                    store.send(.exportTapped)
                                }
                        }
                    }
                }
            }
            .navigationTitle(
                "MaTool"
            )
            .fullScreenCover(item: $store.scope(state: \.destination?.route, action: \.destination.route)) { store in
                RouteView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.info, action: \.destination.info)) { store in
                InfoView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.login, action: \.destination.login)) { store in
                LoginView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.admin, action: \.destination.admin)) { store in
                AdminDistrictView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
                SettingsView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.export, action: \.destination.export)) { store in
                AdminRouteExportView(store: store)
            }
        }
        .onAppear(){
            store.send(.onAppear)
        }
    }
}


