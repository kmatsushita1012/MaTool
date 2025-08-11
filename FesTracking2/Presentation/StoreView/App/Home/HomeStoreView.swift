//
//  AppView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/21.
//

import SwiftUI
import ComposableArchitecture

struct HomeStoreView: View {
    @Bindable var store: StoreOf<Home>
    
    var body: some View  {
        NavigationStack {
            VStack(spacing: 16) {
                CardView(
                    title: "地図",
                    foregroundColor: .white,
                    backgroundColor: .red
                )
                .onTapGesture {
                    store.send(.mapTapped)
                }
                HStack(spacing: 16)  {
                    VStack(spacing: 16)  {
                        CardView(
                            title: "準備中",
                            foregroundColor: .white,
                            backgroundColor: .blue
                        )
                        .onTapGesture{
                            store.send(.infoTapped)
                        }
                        CardView(
                            title: "管理者用\nページ",
                            foregroundColor: .white,
                            backgroundColor: .orange
                        )
                        .onTapGesture {
                            store.send(.adminTapped)
                        }
                        .loadingOverlay(store.isAuthLoading)
                    }
                    VStack(spacing: 16)  {
                        CardView(
                            title: "設定",
                            foregroundColor: .black,
                            backgroundColor: .yellow
                        )
                        .onTapGesture {
                            store.send(.settingsTapped)
                        }
                        CardView(
                            title: "準備中",
                            foregroundColor: .black,
                            backgroundColor: .green
                        )
                        .onTapGesture{}
                    }
                }
            }
            .padding()
            .navigationTitle(
                "MaTool"
            )
            .sheet(item: $store.status) { status in
                AppStatusModal(status)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.route, action: \.destination.route)) { store in
                PublicMapStoreView(store: store)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.info, action: \.destination.info)) { store in
                InfoStoreView(store: store)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.login, action: \.destination.login)) { store in
                LoginStoreView(store: store)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.adminDistrict, action: \.destination.adminDistrict)) { store in
                AdminDistrictView(store: store)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.adminRegion, action: \.destination.adminRegion)) { store in
                AdminRegionView(store: store)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
                SettingsStoreView(store: store)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .loadingOverlay(store.isLoading)
        .onAppear(){
            store.send(.onAppear)
        }
    }
}



