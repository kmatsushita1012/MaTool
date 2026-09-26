//
//  LocationTrackingView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture
import UIKit

@available(iOS 17.0, *)
struct LocationTrackingView: View {
    @SwiftUI.Bindable var store: StoreOf<LocationTrackingFeature>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled
    
    var body: some View {
        List {
            Section(
                footer: Text("始めに短い間隔で試すことで、動作の安定性を確認しやすくなります。")
            ) {
                HStack {
                    Toggle("配信", isOn: $store.isTracking)
                }
                Picker("間隔", selection: $store.selectedInterval) {
                    ForEach(store.intervals, id: \.self) { interval in
                        Text(interval.label)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!store.isPickerEnabled)
            }
            AdminLocationMap(
                showsUserLocation: store.showsUserLocation
            )
                .frame(height: UIScreen.main.bounds.height * 0.3)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(UIColor.separator), lineWidth: 0.5)
                )
                .padding(0)
            if !store.history.isEmpty{
                Section(
                    header: Text("履歴（最新10件）"),
                    footer: Text("送信失敗が続く場合は、アプリの再起動や再ログインをお試しください。")
                ) {
                    ForEach(Array(store.history.suffix(10).reversed().enumerated()), id: \.offset) { _, history in
                        Text(history.text)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("位置情報配信")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !store.isAlwaysLocationAuthorized {
                    Button("権限許可") {
                        store.send(.locationPermissionButtonTapped)
                    }
                }
            }
        }
        .sheet(
            isPresented: $store.isLocationPermissionSheetPresented,
            onDismiss: { store.send(.locationPermissionSheetDismissed) }
        ) {
            LocationPermissionExplanationView(
                mode: store.locationPermissionSheetMode ?? .requestWhenInUseAndAlways,
                onProceed: { store.send(.locationPermissionProceedTapped) }
            )
        }
        .onAppear(){
            store.send(.onAppear)
        }
    }
}

private struct LocationPermissionExplanationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled

    let mode: LocationPermissionSheetMode
    let onProceed: () -> Void

    private var steps: [LocationPermissionStep] {
        switch mode {
        case .requestWhenInUseAndAlways:
            [
                LocationPermissionStep(
                    id: 1,
                    text: "「許可に進む」を押します。"
                ),
                LocationPermissionStep(
                    id: 2,
                    text: "最初に表示されるダイアログで「使用中のみ許可」を選択します。"
                ),
                LocationPermissionStep(
                    id: 3,
                    text: "続いて表示されるダイアログで「常に許可」を選択します。"
                ),
                LocationPermissionStep(
                    id: 4,
                    text: "配信スイッチをオンにします。"
                )
            ]
        case .requestAlways:
            [
                LocationPermissionStep(
                    id: 1,
                    text: "「許可に進む」を押します。"
                ),
                LocationPermissionStep(
                    id: 2,
                    text: "表示されるダイアログで「常に許可」を選択します。"
                ),
                LocationPermissionStep(
                    id: 3,
                    text: "配信スイッチをオンにします。"
                )
            ]
        case .settings:
            [
                LocationPermissionStep(
                    id: 1,
                    text: "「設定を開く」を押します。"
                ),
                LocationPermissionStep(
                    id: 2,
                    text: "「位置情報」を選択します。"
                ),
                LocationPermissionStep(
                    id: 3,
                    text: "「常に」を選択します。"
                ),
                LocationPermissionStep(
                    id: 4,
                    text: "「閉じる」を押して配信スイッチをオンにします。"
                )
            ]
        }
    }

    private var actionTitle: String {
        switch mode {
        case .requestWhenInUseAndAlways, .requestAlways:
            "許可に進む"
        case .settings:
            "設定を開く"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("位置情報の許可が必要です")
                        .font(.title2.weight(.semibold))

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(steps) { step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(step.id).")
                                    .font(.headline.monospacedDigit())
                                Text(step.text)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    proceedButton
                    closeButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .navigationTitle("位置情報配信の使い方")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("閉じる")
                }
            }
        }
    }

    @ViewBuilder
    private var proceedButton: some View {
        if #available(iOS 26.0, *), !isLiquidGlassDisabled {
            Button(action: primaryAction) {
                Text(actionTitle)
                    .frame(maxWidth: .infinity)
            }
                .frame(maxWidth: .infinity)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .buttonStyle(.glassProminent)
                .padding()
        } else {
            Button(action: primaryAction) {
                Text(actionTitle)
                    .frame(maxWidth: .infinity)
            }
                .frame(maxWidth: .infinity)
                .buttonBorderShape(.capsule)
                .buttonStyle(.borderedProminent)
                .padding()
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26.0, *), !isLiquidGlassDisabled {
            Button {
                dismiss()
            } label: {
                Text("閉じる")
                    .frame(maxWidth: .infinity)
            }
                .frame(maxWidth: .infinity)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .buttonStyle(.glass)
                .padding()
        } else {
            Button {
                dismiss()
            } label: {
                Text("閉じる")
                    .frame(maxWidth: .infinity)
            }
                .frame(maxWidth: .infinity)
                .buttonBorderShape(.capsule)
                .buttonStyle(.bordered)
                .padding()
        }
    }

    private func primaryAction() {
        switch mode {
        case .requestWhenInUseAndAlways, .requestAlways:
            onProceed()
        case .settings:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
    }
}

private struct LocationPermissionStep: Identifiable {
    let id: Int
    let text: String
}
