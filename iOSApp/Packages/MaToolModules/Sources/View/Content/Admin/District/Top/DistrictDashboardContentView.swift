import iOSShared
import Shared
import SwiftUI

public struct DistrictDashboardActions {
    public let onEdit: () -> Void
    public let onLocation: () -> Void
    public let onRouteEdit: (RouteSlot) -> Void
    public let onSubmissionExport: () -> Void
    public let onTableExport: () -> Void
    public let onChangePassword: () -> Void
    public let onUpdateEmail: () -> Void
    public let onSignOut: () -> Void

    public init(
        onEdit: @escaping () -> Void,
        onLocation: @escaping () -> Void,
        onRouteEdit: @escaping (RouteSlot) -> Void,
        onSubmissionExport: @escaping () -> Void,
        onTableExport: @escaping () -> Void,
        onChangePassword: @escaping () -> Void,
        onUpdateEmail: @escaping () -> Void,
        onSignOut: @escaping () -> Void
    ) {
        self.onEdit = onEdit
        self.onLocation = onLocation
        self.onRouteEdit = onRouteEdit
        self.onSubmissionExport = onSubmissionExport
        self.onTableExport = onTableExport
        self.onChangePassword = onChangePassword
        self.onUpdateEmail = onUpdateEmail
        self.onSignOut = onSignOut
    }
}

public struct DistrictDashboardContentState {
    public let districtName: String
    public let routes: [RouteSlot]
    public let isSubmissionExportLoading: Bool
    public let isTableExportLoading: Bool
    public let isRouteLoading: Bool
    public let isLocationLoading: Bool
    public let isAWSLoading: Bool
    public let userGuide: URL
    public let contact: URL
    public let version: String

    public init(districtName: String, routes: [RouteSlot], isSubmissionExportLoading: Bool, isTableExportLoading: Bool, isRouteLoading: Bool, isLocationLoading: Bool, isAWSLoading: Bool, userGuide: URL, contact: URL, version: String) {
        self.districtName = districtName
        self.routes = routes
        self.isSubmissionExportLoading = isSubmissionExportLoading
        self.isTableExportLoading = isTableExportLoading
        self.isRouteLoading = isRouteLoading
        self.isLocationLoading = isLocationLoading
        self.isAWSLoading = isAWSLoading
        self.userGuide = userGuide
        self.contact = contact
        self.version = version
    }
}

public struct DistrictDashboardContentView: View {
    let state: DistrictDashboardContentState
    let actions: DistrictDashboardActions

    public init(state: DistrictDashboardContentState, actions: DistrictDashboardActions) {
        self.state = state
        self.actions = actions
    }

    public var body: some View {
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
