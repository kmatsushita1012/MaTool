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
            .sheet(item: $store.folder) { folder in
                ShareSheet(folder.files)
            }
            .navigationDestination(
                item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
            ) { store in
                FestivalEditView(store: store)
            }
            .navigationDestination(
                item: $store.scope(
                    state: \.destination?.districtInfo, action: \.destination.districtInfo)
            ) { store in
                AdminDistrictListView(store: store)
            }
            .navigationDestination(
                item: $store.scope(
                    state: \.destination?.districtCreate, action: \.destination.districtCreate)
            ) { store in
                AdminCreateDistrictView(store: store)
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
            Section(header: Text("参加町")) {
                ForEach(store.districts) { district in
                    NavigationItemView(
                        title: district.name,
                        onTap: {
                            store.send(.onDistrictInfo(district))
                        }
                    )
                }
                Button(action: {
                    store.send(.onCreateDistrict)
                }) {
                    Label("追加", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            #if DEBUG
                Section {
                    Button(action: {
                        store.send(.batchExportTapped)
                    }) {
                        Text("経路図一括出力")
                    }
                }
            #endif
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
