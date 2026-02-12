//
//  FestivalDashboardView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture
import NavigationSwipeControl
import SwiftUI

@available(iOS 17.0, *)
struct FestivalDashboardView: View {
    @SwiftUI.Bindable var store: StoreOf<FestivalDashboardFeature>

    var body: some View {
        content
            .dismissible(backButton: false)
            .navigationDestination(
                item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
            ) { store in
                FestivalEditView(store: store)
            }
            .navigationDestination(
                item: $store.scope(
                    state: \.destination?.districts, action: \.destination.districts)
            ) { store in
                HeadquarterDistrictListView(store: store)
            }
            .navigationDestination(
                item: $store.scope(state: \.destination?.periods, action: \.destination.periods)
            ) { store in
                PeriodListView(store: store)
            }
            .navigationDestination(
                item: $store.scope(
                    state: \.destination?.changePassword, action: \.destination.changePassword)
            ) { store in
                ChangePasswordStoreView(store: store)
            }
            .navigationDestination(
                item: $store.scope(
                    state: \.destination?.updateEmail, action: \.destination.updateEmail)
            ) { store in
                UpdateEmailStoreView(store: store)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .loadingOverlay(store.isLoading)
    }

    @ViewBuilder
    var content: some View {
        List {
            Section {
                NavigationItemView(
                    title: "祭典情報",
                    iconName: "info.circle",
                    onTap: { store.send(.onEdit) })
                NavigationItemView(
                    title: "日程",
                    iconName: "calendar",
                    onTap: { store.send(.periodTapped) })
            }
            
            Section {
                NavigationItemView(
                    title: "参加町一覧",
                    iconName: "list.bullet",
                    onTap: { store.send(.districtsTapped) })
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
            "\(store.festival.name) \(store.festival.subname)"
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    store.send(.homeTapped)
                }) {
                    Image(systemName: "house")
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                }

            }
        }
    }
}
