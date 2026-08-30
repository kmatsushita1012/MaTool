//
//  DistrictDashboardView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct DistrictDashboardScreen: View{
    @SwiftUI.Bindable var store: StoreOf<DistrictDashboardFeature>
    @Dependency(\.values.userGuideUrl) private var userGuideURLString
    @Dependency(\.values.contactURL) private var contactURLString

    private var userGuide: URL { URL(string: userGuideURLString)! }
    private var contact: URL { URL(string: contactURLString)! }
    
    var body: some View {
        let contentState = DistrictDashboardContentState(
            districtName: store.district.name,
            routes: store.routes,
            isSubmissionExportLoading: store.isSubmissionExportLoading,
            isTableExportLoading: store.isTableExportLoading,
            isRouteLoading: store.isRouteLoading,
            isLocationLoading: store.isLocationLoading,
            isAWSLoading: store.isAWSLoading,
            userGuide: userGuide,
            contact: contact,
            version: AppStatusClient.getCurrentVersion()
        )
        let onEdit: () -> Void = { store.send(.onEdit) }
        let onLocation: () -> Void = { store.send(.onLocation) }
        let onRouteEdit: (RouteSlot) -> Void = { store.send(.onRouteEdit($0)) }
        let onSubmissionExport: () -> Void = { store.send(.submissionExportTapped) }
        let onTableExport: () -> Void = { store.send(.tableExportTapped) }
        let onChangePassword: () -> Void = { store.send(.changePasswordTapped) }
        let onUpdateEmail: () -> Void = { store.send(.updateEmailTapped) }
        let onSignOut: () -> Void = { store.send(.signOutTapped) }
        let actions = DistrictDashboardActions(
            onEdit: onEdit,
            onLocation: onLocation,
            onRouteEdit: onRouteEdit,
            onSubmissionExport: onSubmissionExport,
            onTableExport: onTableExport,
            onChangePassword: onChangePassword,
            onUpdateEmail: onUpdateEmail,
            onSignOut: onSignOut
        )

        let contentView: DistrictDashboardContentView = DistrictDashboardContentView(
            state: contentState,
            actions: actions
        )
        destinationView(contentView)
    }

    private func destinationView(_ content: DistrictDashboardContentView) -> some View {
        content
            .fullScreenCover(item: $store.scope(state: \.editDestination, action: \.editDestination)) { destination in
                switch destination.case {
                case .district(let store):
                    DistrictEditView(store: store)
                case .route(let store):
                    RouteEditView(store: store)
                }
            }
            .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .location(let store):
                    LocationTrackingView(store: store)
                case .changePassword(let store):
                    ChangePasswordView(store: store)
                case .updateEmail(let store):
                    UpdateEmailView(store: store)
                }
            }
            .sheet(item: $store.url) { url in
                ShareSheet(item: url)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
    }
}

@available(iOS 17.0, *)
typealias DistrictDashboardView = DistrictDashboardScreen

struct DistrictDashboardActions {
    let onEdit: () -> Void
    let onLocation: () -> Void
    let onRouteEdit: (RouteSlot) -> Void
    let onSubmissionExport: () -> Void
    let onTableExport: () -> Void
    let onChangePassword: () -> Void
    let onUpdateEmail: () -> Void
    let onSignOut: () -> Void
}

struct DistrictDashboardContentState {
    let districtName: String
    let routes: [RouteSlot]
    let isSubmissionExportLoading: Bool
    let isTableExportLoading: Bool
    let isRouteLoading: Bool
    let isLocationLoading: Bool
    let isAWSLoading: Bool
    let userGuide: URL
    let contact: URL
    let version: String
}

struct DistrictDashboardContentView: View {
    let state: DistrictDashboardContentState
    let actions: DistrictDashboardActions

    var body: some View {
        List {
            Section {
                NavigationItemView(title: "地区情報", iconName: "info.circle", onTap: actions.onEdit)
                NavigationItemView(title: "位置情報配信", iconName: "mappin.and.ellipse", onTap: actions.onLocation)
                    .overlay {
                        if state.isLocationLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .disabled(state.isLocationLoading || state.isAWSLoading)
            }
            Section(header: Text("行動")) {
                ForEach(state.routes) { pair in
                    RouteSlotView(pair, onTap: { actions.onRouteEdit(pair) })
                        .overlay {
                            if state.isRouteLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .disabled(state.isRouteLoading || state.isAWSLoading)
                }
            }
            Section(header: Text("ルート出力")) {
                DashboardLoadingButton("提出資料出力", showsProgress: state.isSubmissionExportLoading, isDisabled: state.isSubmissionExportLoading || state.isTableExportLoading, action: actions.onSubmissionExport)
                DashboardLoadingButton("行動表出力", showsProgress: state.isTableExportLoading, isDisabled: state.isSubmissionExportLoading || state.isTableExportLoading, action: actions.onTableExport)
            }
            Section {
                Button("パスワード変更", action: actions.onChangePassword)
                Button("メールアドレス変更", action: actions.onUpdateEmail)
            }
            Section {
                Button("ログアウト", role: .destructive, action: actions.onSignOut)
                    .overlay {
                        if state.isAWSLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .disabled(state.isAWSLoading)
            }
            Section {
                Link("MaToolの使い方", destination: state.userGuide)
                Link("お問い合わせ", destination: state.contact)
                LabeledContent("バージョン", value: state.version)
            }
        }
        .navigationTitle(state.districtName)
        .navigationBarTitleDisplayMode(.large)
    }

}

private struct DashboardLoadingButton: View {
    let title: String
    let showsProgress: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        showsProgress: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.showsProgress = showsProgress
        self.isDisabled = isDisabled
        self.action = action
    }

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
