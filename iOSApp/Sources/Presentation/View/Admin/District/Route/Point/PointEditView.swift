//
//  PointEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/08.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl
import Shared

@available(iOS 17.0, *)
struct PointEditView: View {
    
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled: Bool
    @SwiftUI.Bindable var store: StoreOf<PointEditFeature>
    
    var body: some View {
        Form {
            Section {
                Picker("地点の種類", selection: $store.pointType) {
                    ForEach(store.validTypes, id: \.self){ type in
                        Text(type.text).tag(type)
                    }
                }
                .pickerStyle(.menu)
                
                switch store.pointType {
                case .checkpoint:
                    checkpoint
                case .performance:
                    performance
                case .start, .end, .rest:
                    timePicker
                case .none:
                    EmptyView()
                }
            }
            
            Section {
                Toggle("ここから色を変更", isOn: $store.point.isBoundary)
            } footer: {
                Text("経路が重なって見にくい場合は、この地点から表示色を変更できます。")
            }
            
            Section {
                Button("この地点を移動", systemImage: "arrow.up.right"){
                    store.send(.moveTapped)
                }
                Button("この地点の前に新しい地点を挿入", systemImage: "arrow.turn.left.up"){
                    store.send(.insertBeforeTapped)
                }
                Button("この地点の後に新しい地点を挿入", systemImage: "arrow.turn.right.up"){
                    store.send(.insertAfterTapped)
                }
            } footer: {
                Text("ボタンを押した後、地図を長押しして地点の移動・挿入ができます。")
            }
            Section {
                Button(action: {
                    store.send(.deleteTapped)
                }) {
                    Label("この地点を削除", systemImage: "trash")
                        .font(.body)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("地点")
        .navigationBarTitleDisplayMode(.inline)
        .alert($store.scope(state: \.alert, action: \.alert))
        .toolbar {
            ToolbarCancelButton {
                store.send(.cancelTapped)
            }
            ToolbarDoneButton {
                store.send(.doneTapped)
            }
        }
    }
    
    @ViewBuilder
    var checkpoint: some View {
        if #available(iOS 18.0, *) {
            Picker("重要地点の種類", selection: $store.point.checkpointId) {
                checkpointPickerContent
            } currentValueLabel: {
                Text(store.selectedCheckpoint?.name ?? "未選択")
            }
            .pickerStyle(.menu)
        } else {
            Picker("重要地点の種類", selection: $store.point.checkpointId) {
               checkpointPickerContent
            }
            .pickerStyle(.menu)
        }
        timePicker
    }
    
    @ViewBuilder
    var checkpointPickerContent: some View {
        ForEach(store.checkpoints){ checkpoint in
            Text(checkpoint.name).tag(Optional(checkpoint.id))
        }
    }
    
    @ViewBuilder
    var performance: some View {
        if #available(iOS 18.0, *) {
            Picker("余興の種類", selection: $store.point.performanceId) {
                performancePickerContent
            } currentValueLabel: {
                Text(store.selectedPerformance?.name ?? "未選択")
            }
            .pickerStyle(.menu)
        } else {
            Picker(
                "余興の種類",
                selection: $store.point.performanceId
            ) {
                performancePickerContent
            }
            .pickerStyle(.menu)
        }
        optionalTimePicker
    }
    
    @ViewBuilder
    var performancePickerContent: some View {
        ForEach(store.performances){ performance in
            Text(performance.name).tag(Optional(performance.id))
        }
    }
    
    @ViewBuilder
    var timePicker: some View {
        TimePicker("時刻を選択", selection: $store.point.time.unwrapped)
        .datePickerStyle(.compact)
    }
    
    @ViewBuilder
    var optionalTimePicker: some View {
        Toggle("時刻を設定", isOn: $store.point.time.toggle)
        if store.point.time != nil {
            timePicker
        }
    }
}

fileprivate extension PointEditFeature.PointType {
    var text: String {
        switch self {
        case .checkpoint:
            return "重要地点（交差点等）"
        case .performance:
            return "余興"
        case .start:
            return "出発地点"
        case .end:
            return "到着地点"
        case .rest:
            return "休憩"
        case .none:
            return "なし"
        }
    }
}
