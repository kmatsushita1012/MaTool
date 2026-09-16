import SwiftUI

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
