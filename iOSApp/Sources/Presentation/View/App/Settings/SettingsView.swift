//
//  SettingsView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/21.
//

import ComposableArchitecture
import SwiftUI
import NavigationSwipeControl
import Shared


struct SettingsScreen: View {
    @SwiftUI.Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking{
            SettingsContentView(
                festivals: store.festivals,
                districts: store.districts,
                selectedFestival: $store.selectedFestival,
                selectedDistrict: $store.selectedDistrict,
                userGuide: store.userGuide,
                contact: store.contact,
                appVersion: AppStatusClient.getCurrentVersion(),
                isDismissEnabled: store.isDismissEnabled,
                onDismissTapped: { store.send(.dismissTapped) },
                onSignOutTapped: { store.send(.signOutTapped) }
            )
            .preferredColorScheme(.light)
            .dismissible(backButton: false)
            .alert($store.scope(state: \.alert, action: \.alert))
            .loadingOverlay(store.isLoading)
            .ignoresSafeArea(edges: .top)
        }
    }
}

typealias SettingsView = SettingsScreen

struct SettingsContentView: View {
    let festivals: [Festival]
    let districts: [District]
    @Binding var selectedFestival: Festival?
    @Binding var selectedDistrict: District?
    let userGuide: URL
    let contact: URL
    let appVersion: String
    let isDismissEnabled: Bool
    let onDismissTapped: () -> Void
    let onSignOutTapped: () -> Void

    var body: some View {
        VStack(spacing: 8){
            TitleView(
                text: "設定",
                image: "SettingsBackground",
                isDismissEnabled: isDismissEnabled
            ) {
                onDismissTapped()
            }
            .ignoresSafeArea(edges: .top)
            VStack(spacing: 8){
                VStack{
                    MenuSelector(
                        title: "祭典を変更",
                        items: festivals,
                        selection: $selectedFestival,
                        label: { festival in
                            festival?.name ?? "未設定"
                        },
                        isNullable: false
                    )
                    MenuSelector(
                        title: "参加町を変更",
                        items: districts,
                        selection: $selectedDistrict,
                        label: { district in
                            district?.name ?? "未設定"
                        }
                    )
                }
                .padding(.vertical, 8)
                VStack(alignment: .leading){
                    Link(destination: userGuide) {
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
                    Link(destination: contact) {
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
                Text("バージョン \(appVersion)")
                VStack{
                    Button(action: onSignOutTapped) {
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
    }
}

#Preview {
    SettingsContentView(
        festivals: [],
        districts: [],
        selectedFestival: .constant(nil),
        selectedDistrict: .constant(nil),
        userGuide: URL(string: "https://example.com")!,
        contact: URL(string: "https://example.com")!,
        appVersion: "",
        isDismissEnabled: true,
        onDismissTapped: {},
        onSignOutTapped: {}
    )
}
