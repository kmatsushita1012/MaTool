import iOSShared
import SwiftUI

public struct FestivalDashboardActions {
    let onEdit: () -> Void
    let onPeriods: () -> Void
    let onDistricts: () -> Void
    let onChangePassword: () -> Void
    let onUpdateEmail: () -> Void
    let onSignOut: () -> Void

    public init(
        onEdit: @escaping () -> Void,
        onPeriods: @escaping () -> Void,
        onDistricts: @escaping () -> Void,
        onChangePassword: @escaping () -> Void,
        onUpdateEmail: @escaping () -> Void,
        onSignOut: @escaping () -> Void
    ) {
        self.onEdit = onEdit
        self.onPeriods = onPeriods
        self.onDistricts = onDistricts
        self.onChangePassword = onChangePassword
        self.onUpdateEmail = onUpdateEmail
        self.onSignOut = onSignOut
    }
}

public struct FestivalDashboardContentState {
    let title: String
    let isAuthLoading: Bool
    let userGuide: URL
    let contact: URL
    let version: String

    public init(title: String, isAuthLoading: Bool, userGuide: URL, contact: URL, version: String) {
        self.title = title
        self.isAuthLoading = isAuthLoading
        self.userGuide = userGuide
        self.contact = contact
        self.version = version
    }
}

public struct FestivalDashboardContentView: View {
    let state: FestivalDashboardContentState
    let actions: FestivalDashboardActions

    public init(state: FestivalDashboardContentState, actions: FestivalDashboardActions) {
        self.state = state
        self.actions = actions
    }

    public var body: some View {
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
                Button(action: actions.onChangePassword) {
                    Text("パスワード変更")
                }
                Button(action: actions.onUpdateEmail) {
                    Text("メールアドレス変更")
                }
            }
            Section {
                Button(action: actions.onSignOut) {
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
        .navigationTitle(state.title)
        .navigationBarTitleDisplayMode(.large)
    }
}
