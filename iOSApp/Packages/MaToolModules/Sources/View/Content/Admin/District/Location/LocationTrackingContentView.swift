import iOSShared
//
//  LocationTrackingContentView.swift
//  MaTool
//

import SwiftUI

@available(iOS 17.0, *)
public struct LocationTrackingContentView<MapContent: View>: View {
    @Binding var isTracking: Bool
    @Binding var selectedInterval: Interval
    let intervals: [Interval]
    let isPickerEnabled: Bool
    let history: [Status]
    private let map: () -> MapContent

    public init(
        isTracking: Binding<Bool>,
        selectedInterval: Binding<Interval>,
        intervals: [Interval],
        isPickerEnabled: Bool,
        history: [Status],
        @ViewBuilder map: @escaping () -> MapContent
    ) {
        self._isTracking = isTracking
        self._selectedInterval = selectedInterval
        self.intervals = intervals
        self.isPickerEnabled = isPickerEnabled
        self.history = history
        self.map = map
    }

    public var body: some View {
        List {
            Section(
                footer: Text("始めに短い間隔で試すことで、動作の安定性を確認しやすくなります。")
            ) {
                Toggle("配信", isOn: $isTracking)
                Picker("間隔", selection: $selectedInterval) {
                    ForEach(intervals, id: \.self) { interval in
                        Text(interval.label)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!isPickerEnabled)
            }
            map()
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
            if !history.isEmpty {
                Section(
                    header: Text("履歴（最新10件）"),
                    footer: Text("送信失敗が続く場合は、アプリの再起動や再ログインをお試しください。")
                ) {
                    ForEach(history.suffix(10).reversed(), id: \.self) { item in
                        Text(item.text)
                            .font(.body)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}
