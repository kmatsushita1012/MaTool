import iOSShared
import SwiftUI
import Shared

public struct SettingsContentView: View {
    let festivals: [Festival]
    @Binding var selectedFestival: Festival?
    let districts: [District]
    @Binding var selectedDistrict: District?
    @Binding var isMapInfoLinked: Bool
    let isLoading: Bool
    let userGuide: URL
    let contact: URL
    let version: String
    let onLogin: () -> Void

    public init(
        festivals: [Festival],
        selectedFestival: Binding<Festival?>,
        districts: [District],
        selectedDistrict: Binding<District?>,
        isMapInfoLinked: Binding<Bool>,
        isLoading: Bool,
        userGuide: URL,
        contact: URL,
        version: String,
        onLogin: @escaping () -> Void
    ) {
        self.festivals = festivals
        self._selectedFestival = selectedFestival
        self.districts = districts
        self._selectedDistrict = selectedDistrict
        self._isMapInfoLinked = isMapInfoLinked
        self.isLoading = isLoading
        self.userGuide = userGuide
        self.contact = contact
        self.version = version
        self.onLogin = onLogin
    }

    public var body: some View {
        Form {
            Section("参加設定") {
                Picker("祭典", selection: $selectedFestival) {
                    Text("未設定").tag(Optional<Festival>.none)
                    ForEach(festivals) { festival in
                        Text(festival.name).tag(Optional(festival))
                    }
                }
                .pickerStyle(.menu)
                .disabled(isLoading)
                .overlay(alignment: .trailing) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Picker("町", selection: $selectedDistrict) {
                    Text("未設定").tag(Optional<District>.none)
                    ForEach(districts) { district in
                        Text(district.name).tag(Optional(district))
                    }
                }
                .pickerStyle(.menu)
                .disabled(selectedFestival == nil || isLoading)
                .overlay(alignment: .trailing) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Toggle("地図と紹介を連動", isOn: $isMapInfoLinked)
            }

            Section("アカウント") {
                Button("ログイン", systemImage: "person.crop.circle", action: onLogin)
            }

            Section("サポート") {
                Link("MaToolの使い方", destination: userGuide)
                Link("お問い合わせ", destination: contact)
                LabeledContent("バージョン", value: version)
            }
        }
        .navigationTitle("設定")
    }
}
