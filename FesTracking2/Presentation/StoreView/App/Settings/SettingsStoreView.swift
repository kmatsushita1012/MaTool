//
//  SettingsStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/21.
//

import ComposableArchitecture
import SwiftUI
import NavigationSwipeControl

struct SettingsStoreView: View {
    @Bindable var store: StoreOf<Settings>
    
    var body: some View {
        VStack{
            TitleView(
                text: "設定",
                image: "SettingsBackground",
                isDismissEnabled: store.isDismissEnabled
            ) {
                store.send(.dismissTapped)
            }
            .ignoresSafeArea(edges: .top)
            Spacer()
            VStack{
                MenuSelector(
                    title: "祭典を変更",
                    items: store.regions,
                    selection: $store.selectedRegion,
                    label: { region in
                        region?.name ?? "未設定"
                    },
                    isNullable: false
                )
                MenuSelector(
                    title: "参加町を変更",
                    items: store.districts,
                    selection: $store.selectedDistrict,
                    label: { district in
                        district?.name ?? "未設定"
                    }
                )
            }
            .padding()
            Spacer()
            VStack(alignment: .leading){
                Link(destination: store.userGuide) {
                    HStack {
                        Image("LeftDoubleArrow")
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text("MaToolの使い方")
                            .font(.headline)
                        Spacer()
                    }
                    .font(.headline)
                }
                Link(destination: store.contact) {
                    HStack {
                        Image("LeftDoubleArrow")
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text("お問い合わせ")
                            .font(.headline)
                        Spacer()
                    }
                    .font(.headline)
                }
            }
            .padding()
            Spacer()
            Button(action: {
                store.send(.signOutTapped)
            }) {
                Text("強制ログアウト")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            Text("※この操作は管理者のみ有効です")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .dismissible(backButton: false)
        .alert($store.scope(state: \.alert, action: \.alert))
        .loadingOverlay(store.isLoading)
        .ignoresSafeArea(edges: .top)
    }
}
