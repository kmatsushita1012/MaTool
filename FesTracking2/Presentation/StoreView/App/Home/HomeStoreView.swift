//
//  AppView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/21.
//

import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<Home>
    

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                CardItem {
                    Text("地図")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    store.send(.routeTapped)
                }
                .background(.red)
                .cornerRadius(8)
                HStack(spacing: 16)  {
                    VStack(spacing: 16)  {
                        CardItem {
                            Text("準備中")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.infoTapped)
                        }
                        .background(.blue)
                        .cornerRadius(8)
                        CardItem {
                            Text("管理者用\nページ")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.adminTapped)
                        }
                        .background(.orange)
                        .cornerRadius(8)
                    }
                    VStack(spacing: 16)  {
                        CardItem {
                            Text("設定")
                                .font(.title3)
                                .foregroundStyle(.black)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.settingsTapped)
                        }
                        .background(.yellow)
                        .cornerRadius(8)
                        CardItem {
                            Text("準備中")
                                .font(.title3)
                                .foregroundStyle(.black)
                        }
                        .contentShape(Rectangle())
                        .background(.green)
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
            .navigationTitle(
                "MaTool"
            )
            .fullScreenCover(item: $store.scope(state: \.destination?.route, action: \.destination.route)) { store in
                PublicMapStoreView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.info, action: \.destination.info)) { store in
                InfoStoreView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.login, action: \.destination.login)) { store in
                LoginStoreView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.adminDistrict, action: \.destination.adminDistrict)) { store in
                AdminDistrictView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.adminRegion, action: \.destination.adminRegion)) { store in
                AdminRegionView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
                SettingsStoreView(store: store)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .loadingOverlay(store.isLoading)
        }
        .onAppear(){
            store.send(.onAppear)
        }
    }
}



