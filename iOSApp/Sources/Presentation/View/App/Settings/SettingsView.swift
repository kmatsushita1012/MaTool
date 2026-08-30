//
//  SettingsView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/21.
//

import ComposableArchitecture
import SwiftUI
import Shared

struct SettingsScreen: View {
    @Perception.Bindable var store: StoreOf<SettingsFeature>
    
    var body: some View {
        WithPerceptionTracking{
            SettingsContentView(
                festivals: store.festivals,
                selectedFestival: $store.selectedFestival,
                districts: store.districts,
                selectedDistrict: $store.selectedDistrict,
                isMapInfoLinked: $store.isMapInfoLinked,
                isLoading: store.isLoading,
                userGuide: store.userGuide,
                contact: store.contact,
                version: AppStatusClient.getCurrentVersion(),
                onLogin: { store.send(.loginTapped) }
            )
            .alert($store.scope(state: \.alert, action: \.alert))
            .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .login(let store):
                    if #available(iOS 17.0, *) {
                        LoginView(store: store)
                    } else {
                        EmptyView()
                    }
                }
            }
        }
    }
}

typealias SettingsView = SettingsScreen

struct SettingsContentView: View {
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

    var body: some View {
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
