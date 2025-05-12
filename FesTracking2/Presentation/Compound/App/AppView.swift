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
        NavigationStack {
            VStack(spacing: 16) {
                CardView {
                    Text("地図")
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
                        CardView {
                            Text("紹介")
                                .foregroundStyle(.white)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.infoTapped)
                        }
                        .background(.blue)
                        .cornerRadius(8)
                        CardView {
                            Text("編集")
                                .foregroundStyle(.white)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.adminTapped)
                        }
                        .background(.orange)
                        .cornerRadius(8)
                    }
                    VStack(spacing: 16)  {
                        CardView {
                            Text("設定")
                                .foregroundStyle(.black)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.settingsTapped)
                        }
                        .background(.yellow)
                        .cornerRadius(8)
                        CardView {
                            Text("準備中")
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
                RouteView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.info, action: \.destination.info)) { store in
                InfoView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.login, action: \.destination.login)) { store in
                LoginView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.districtAdmin, action: \.destination.districtAdmin)) { store in
                AdminDistrictView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.regionAdmin, action: \.destination.regionAdmin)) { store in
                AdminRegionView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
                SettingsView(store: store)
            }
        }
        .onAppear(){
            store.send(.onAppear)
        }
    }
}


struct CardView<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

