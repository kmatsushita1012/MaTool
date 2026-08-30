//
//  FestivalDashboardView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture
import SwiftUI

@available(iOS 17.0, *)
struct FestivalDashboardScreen: View {
    @SwiftUI.Bindable var store: StoreOf<FestivalDashboardFeature>
    @Dependency(\.values.userGuideUrl) private var userGuideURLString
    @Dependency(\.values.contactURL) private var contactURLString

    private var userGuide: URL { URL(string: userGuideURLString)! }
    private var contact: URL { URL(string: contactURLString)! }

    var body: some View {
        let contentState = FestivalDashboardContentState(
            title: "\(store.festival.name) \(store.festival.subname)",
            isAuthLoading: store.isAuthLoading,
            userGuide: userGuide,
            contact: contact,
            version: AppStatusClient.getCurrentVersion()
        )
        let actions = FestivalDashboardActions(
            onEdit: { store.send(.onEdit) },
            onPeriods: { store.send(.periodTapped) },
            onDistricts: { store.send(.districtsTapped) },
            onChangePassword: { store.send(.changePasswordTapped) },
            onUpdateEmail: { store.send(.updateEmailTapped) },
            onSignOut: { store.send(.signOutTapped) }
        )

        let contentView: FestivalDashboardContentView = FestivalDashboardContentView(
            state: contentState,
            actions: actions
        )
        destinationView(contentView)
    }

    private func destinationView(_ content: FestivalDashboardContentView) -> some View {
        content
            .fullScreenCover(
                item: $store.scope(state: \.editDestination, action: \.editDestination)
            ) { destination in
                switch destination.case {
                case .festival(let store):
                    FestivalEditView(store: store)
                }
            }
            .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .districts(let store):
                    HeadquarterDistrictListView(store: store)
                case .periods(let store):
                    PeriodListView(store: store)
                case .changePassword(let store):
                    ChangePasswordView(store: store)
                case .updateEmail(let store):
                    UpdateEmailView(store: store)
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
    }

}

@available(iOS 17.0, *)
typealias FestivalDashboardView = FestivalDashboardScreen

struct FestivalDashboardActions {
    let onEdit: () -> Void
    let onPeriods: () -> Void
    let onDistricts: () -> Void
    let onChangePassword: () -> Void
    let onUpdateEmail: () -> Void
    let onSignOut: () -> Void
}

struct FestivalDashboardContentState {
    let title: String
    let isAuthLoading: Bool
    let userGuide: URL
    let contact: URL
    let version: String
}

struct FestivalDashboardContentView: View {
    let state: FestivalDashboardContentState
    let actions: FestivalDashboardActions

    var body: some View {
        List {
            Section {
                NavigationItemView(
                    title: "祭典情報",
                    iconName: "info.circle",
                    onTap: actions.onEdit)
                NavigationItemView(
                    title: "日程",
                    iconName: "calendar",
                    onTap: actions.onPeriods)
            }
            
            Section {
                NavigationItemView(
                    title: "参加町一覧",
                    iconName: "list.bullet",
                    onTap: actions.onDistricts)
            }
            
            Section {
                Button(action: {
                    actions.onChangePassword()
                }) {
                    Text("パスワード変更")
                }
                Button(action: {
                    actions.onUpdateEmail()
                }) {
                    Text("メールアドレス変更")
                }
            }
            Section {
                Button(action: {
                    actions.onSignOut()
                }) {
                    Text("ログアウト")
                        .foregroundColor(.red)
                }
                .overlay {
                    if state.isAuthLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .disabled(state.isAuthLoading)
            }
            Section {
                Link("MaToolの使い方", destination: state.userGuide)
                Link("お問い合わせ", destination: state.contact)
                LabeledContent("バージョン", value: state.version)
            }
        }
        .navigationTitle(
            state.title
        )
        .navigationBarTitleDisplayMode(.large)
    }
}
