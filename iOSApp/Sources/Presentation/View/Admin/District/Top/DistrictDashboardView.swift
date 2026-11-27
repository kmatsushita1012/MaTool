//
//  DistrictDashboardView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture
import Shared

struct DistrictDashboardScreen: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictDashboardFeature>

    var body: some View {
        DistrictDashboardContentView(
            districtName: store.district.name,
            routes: store.routes,
            isNavigationLoading: store.isNavigationLoading,
            isSubmissionExportLoading: store.isSubmissionExportLoading,
            isTableExportLoading: store.isTableExportLoading,
            isSignOutLoading: store.isAWSLoading,
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
        .fullScreenCover(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) { store in
            NavigationStack {
                DistrictEditView(store: store)
            }
        }
        .navigationDestination(item: $store.scope(state: \.destination?.location, action: \.destination.location)) { store in
            LocationTrackingView(store: store)
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.route, action: \.destination.route)) { store in
            NavigationStack {
                RouteEditView(store: store)
            }
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.changePassword, action: \.destination.changePassword)) { store in
            NavigationStack {
                ChangePasswordView(store: store)
            }
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.updateEmail, action: \.destination.updateEmail)) { store in
            NavigationStack {
                UpdateEmailView(store: store)
            }
        }
        .navigationDestination(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
            SettingsView(store: store)
        }
        .sheet(item: $store.url) { url in
            ShareSheet(item: url)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

typealias DistrictDashboardView = DistrictDashboardScreen

struct DistrictDashboardContentView: View {
    let districtName: String
    let routes: [RouteSlot]
    let isNavigationLoading: Bool
    let isSubmissionExportLoading: Bool
    let isTableExportLoading: Bool
    let isSignOutLoading: Bool
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
                .disabled(isNavigationLoading)
                NavigationItemView(
                    title: "位置情報配信",
                    iconName: "mappin.and.ellipse",
                    onTap: onLocationTapped
                )
                .disabled(isNavigationLoading)
            }
            Section(header: Text("行動")) {
                ForEach(routes) { pair in
                    RouteSlotView(pair) {
                        onRouteTapped(pair)
                    }
                    .disabled(isNavigationLoading)
                }
            }
            Section(header: Text("ルート出力")) {
                DashboardExportButton(
                    title: "提出資料出力",
                    showsProgress: isSubmissionExportLoading,
                    isDisabled: isSubmissionExportLoading || isTableExportLoading || isSignOutLoading,
                    action: onSubmissionExportTapped
                )
                DashboardExportButton(
                    title: "行動表出力",
                    showsProgress: isTableExportLoading,
                    isDisabled: isSubmissionExportLoading || isTableExportLoading || isSignOutLoading,
                    action: onTableExportTapped
                )
            }
            Section {
                Button("パスワード変更", action: onChangePasswordTapped)
                    .disabled(isNavigationLoading)
                Button("メールアドレス変更", action: onUpdateEmailTapped)
                    .disabled(isNavigationLoading)
            }
            Section {
                Button("ログアウト", action: onSignOutTapped)
                    .foregroundColor(.red)
                    .loadingIndicator(isLoading: isSignOutLoading)
            }
        }
        .navigationTitle(districtName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("設定", systemImage: "gearshape", action: onSettingsTapped)
                    .disabled(isNavigationLoading || isSignOutLoading)
            }
        }
    }
}

#Preview {
    DistrictDashboardContentView(
        districtName: "",
        routes: [],
        isNavigationLoading: false,
        isSubmissionExportLoading: false,
        isTableExportLoading: false,
        isSignOutLoading: false,
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
