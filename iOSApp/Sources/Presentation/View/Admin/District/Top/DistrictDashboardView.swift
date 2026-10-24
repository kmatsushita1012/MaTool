//
//  DistrictDashboardView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl
import Shared

@available(iOS 17.0, *)
struct DistrictDashboardScreen: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictDashboardFeature>

    var body: some View {
        WithPerceptionTracking {
            DistrictDashboardContentView(
                districtName: store.district.name,
                routes: store.routes,
                isSubmissionExportLoading: store.isSubmissionExportLoading,
                isTableExportLoading: store.isTableExportLoading,
                onEditTapped: { store.send(.onEdit) },
                onLocationTapped: { store.send(.onLocation) },
                onRouteTapped: { store.send(.onRouteEdit($0)) },
                onSubmissionExportTapped: { store.send(.submissionExportTapped) },
                onTableExportTapped: { store.send(.tableExportTapped) },
                onChangePasswordTapped: { store.send(.changePasswordTapped) },
                onUpdateEmailTapped: { store.send(.updateEmailTapped) },
                onSignOutTapped: { store.send(.signOutTapped) },
                onSettingsTapped: { store.send(.settingsTapped) }
            )
            .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .edit(let store):
                    DistrictEditView(store: store)
                case .location(let store):
                    LocationTrackingView(store: store)
                case .route(let store):
                    RouteEditView(store: store)
                case .changePassword(let store):
                    ChangePasswordView(store: store)
                case .updateEmail(let store):
                    UpdateEmailView(store: store)
                case .settings(let store):
                    SettingsView(store: store)
                }
            }
            .sheet(item: $store.url) { url in
                ShareSheet(item: url)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .loadingOverlay(store.isLoading)
        }
    }
}

@available(iOS 17.0, *)
typealias DistrictDashboardView = DistrictDashboardScreen

@available(iOS 17.0, *)
struct DistrictDashboardContentView: View {
    let districtName: String
    let routes: [RouteSlot]
    let isSubmissionExportLoading: Bool
    let isTableExportLoading: Bool
    let onEditTapped: () -> Void
    let onLocationTapped: () -> Void
    let onRouteTapped: (RouteSlot) -> Void
    let onSubmissionExportTapped: () -> Void
    let onTableExportTapped: () -> Void
    let onChangePasswordTapped: () -> Void
    let onUpdateEmailTapped: () -> Void
    let onSignOutTapped: () -> Void
    let onSettingsTapped: () -> Void

    var body: some View {
        List {
            Section {
                NavigationItemView(
                    title: "地区情報",
                    iconName: "info.circle",
                    onTap: onEditTapped
                )
                NavigationItemView(
                    title: "位置情報配信",
                    iconName: "mappin.and.ellipse",
                    onTap: onLocationTapped
                )
            }
            Section(header: Text("行動")) {
                ForEach(routes) { pair in
                    RouteSlotView(pair) {
                        onRouteTapped(pair)
                    }
                }
            }
            Section(header: Text("ルート出力")) {
                DashboardExportButton(
                    title: "提出資料出力",
                    showsProgress: isSubmissionExportLoading,
                    isDisabled: isSubmissionExportLoading || isTableExportLoading,
                    action: onSubmissionExportTapped
                )
                DashboardExportButton(
                    title: "行動表出力",
                    showsProgress: isTableExportLoading,
                    isDisabled: isSubmissionExportLoading || isTableExportLoading,
                    action: onTableExportTapped
                )
            }
            Section {
                Button("パスワード変更", action: onChangePasswordTapped)
                Button("メールアドレス変更", action: onUpdateEmailTapped)
            }
            Section {
                Button("ログアウト", action: onSignOutTapped)
                    .foregroundColor(.red)
            }
        }
        .navigationTitle(districtName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("設定", systemImage: "gearshape", action: onSettingsTapped)
            }
        }
    }
}

#Preview {
    DistrictDashboardContentView(
        districtName: "",
        routes: [],
        isSubmissionExportLoading: false,
        isTableExportLoading: false,
        onEditTapped: {},
        onLocationTapped: {},
        onRouteTapped: { _ in },
        onSubmissionExportTapped: {},
        onTableExportTapped: {},
        onChangePasswordTapped: {},
        onUpdateEmailTapped: {},
        onSignOutTapped: {},
        onSettingsTapped: {}
    )
}

private struct DashboardExportButton: View {
    let title: String
    let showsProgress: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .trailing) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .disabled(isDisabled)
    }
}
