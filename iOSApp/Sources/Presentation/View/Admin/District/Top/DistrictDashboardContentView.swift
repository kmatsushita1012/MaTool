import Shared
import SwiftUI

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
