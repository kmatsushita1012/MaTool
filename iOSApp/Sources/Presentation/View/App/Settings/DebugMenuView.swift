#if DEBUG
import ComposableArchitecture
import SwiftUI

struct DebugMenuView: View {
    @SwiftUI.Bindable var store: StoreOf<DebugMenuFeature>

    var body: some View {
        Form {
            Section {
                Picker("API環境", selection: $store.apiEnvironment) {
                    Text("prod").tag(DebugAPIEnvironment.prod)
                    Text("dev").tag(DebugAPIEnvironment.dev)
                    Text("自由入力").tag(DebugAPIEnvironment.custom)
                }
                .pickerStyle(.menu)

                if store.apiEnvironment == .custom {
                    TextField("dev-xxx-yyy", text: $store.customStage)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("API環境設定")
            } footer: {
                if store.apiEnvironment == .custom {
                    Text(#"backend/xxx-yyyを検証する場合は"dev-xxx-yyy"と入力してください"#)
                }
            }
        }
        .navigationTitle("DebugMenu")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる", systemImage: "xmark") {
                    store.send(.closeTapped)
                }
            }
        }
    }
}
#endif
