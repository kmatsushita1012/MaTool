//
//  SettingsView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/21.
//

import ComposableArchitecture
import SwiftUI
import NavigationSwipeControl


struct SettingsView: View {
    @Perception.Bindable var store: StoreOf<SettingsFeature>
    
    var body: some View {
        WithPerceptionTracking{
            VStack(spacing: 8){
                TitleView(
                    text: "設定",
                    image: "SettingsBackground",
                    isDismissEnabled: store.isDismissEnabled
                ) {
                    store.send(.dismissTapped)
                }
                .ignoresSafeArea(edges: .top)
                VStack(spacing: 8){
                    VStack{
                        MenuSelector(
                            title: "祭典を変更",
                            items: store.festivals,
                            selection: $store.selectedFestival,
                            label: { festival in
                                festival?.name ?? "未設定"
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
                    .padding(.vertical, 8)
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
                    Text("バージョン \(AppStatusClient.getCurrentVersion())")
                    VStack{
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
                    Spacer()
                }
                .padding(.horizontal)
            }
            .preferredColorScheme(.light)
            .dismissible(backButton: false)
            .alert($store.scope(state: \.alert, action: \.alert))
            .loadingOverlay(store.isLoading)
            .ignoresSafeArea(edges: .top)
        }
    }
}
