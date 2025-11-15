//
//  LocationAdminView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct LocationAdminView: View {
    @SwiftUI.Bindable var store: StoreOf<AdminLocation>
    
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
            AdminLocationMap(location: store.location)
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
                    ForEach(store.history.suffix(10).reversed(), id: \.self) { history in
                        Text(history.text)
                            .font(.body)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("位置情報配信")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(){
            store.send(.onAppear)
        }
    }
}
