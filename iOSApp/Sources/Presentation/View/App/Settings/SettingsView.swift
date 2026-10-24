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
    @SwiftUI.Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsContentView(
                festivals: store.festivals,
                districts: store.districts,
                selectedFestival: $store.selectedFestival,
                selectedDistrict: $store.selectedDistrict,
                userGuide: store.userGuide,
                contact: store.contact,
                appVersion: AppStatusClient.getCurrentVersion(),
                userRole: store.userRole,
                isLoading: store.isLoading,
                onLoginTapped: { store.send(.loginTapped) },
                onSignOutTapped: { store.send(.signOutTapped) }
            )
            .navigationDestination(item: $store.scope(
                state: \.destination?.login,
                action: \.destination.login
            )) { store in
                LoginView(store: store)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .loadingOverlay(store.isLoading)
        }
    }
}

typealias SettingsView = SettingsScreen

struct SettingsContentView: View {
    let festivals: [Festival]
    let districts: [District]
    @Binding var selectedFestival: Festival?
    @Binding var selectedDistrict: District?
    let userGuide: URL?
    let contact: URL?
    let appVersion: String
    let userRole: UserRole
    let isLoading: Bool
    let onLoginTapped: () -> Void
    let onSignOutTapped: () -> Void

    var body: some View {
        Form {
            Section("参加設定") {
                Picker("祭典", selection: $selectedFestival) {
                    if festivals.isEmpty {
                        Text("未設定").tag(Optional<Festival>.none)
                    }
                    ForEach(festivals) { festival in
                        Text(festival.name).tag(Optional(festival))
                    }
                }
                .pickerStyle(.menu)
                .disabled(festivals.isEmpty || isLoading)
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
            }

            Section("アカウント") {
                if userRole == .guest {
                    Button("管理者ログイン", systemImage: "person.badge.key", action: onLoginTapped)
                } else {
                    Button("ログアウト", role: .destructive, action: onSignOutTapped)
                }
            }

            Section("サポート") {
                if let userGuide {
                    Link("MaToolの使い方", destination: userGuide)
                }
                if let contact {
                    Link("お問い合わせ", destination: contact)
                }
                LabeledContent("バージョン", value: appVersion)
            }
        }
        .navigationTitle("設定")
    }
}

#Preview {
    SettingsContentView(
        festivals: [],
        districts: [],
        selectedFestival: .constant(nil),
        selectedDistrict: .constant(nil),
        userGuide: nil,
        contact: nil,
        appVersion: "",
        userRole: .guest,
        isLoading: false,
        onLoginTapped: {},
        onSignOutTapped: {}
    )
}
