//
//  PointEditContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
struct PointEditContentView: View {
    @Binding var point: Point
    @Binding var pointType: PointEditFeature.PointType
    let validTypes: [PointEditFeature.PointType]
    let checkpoints: [Checkpoint]
    let performances: [Performance]
    let selectedCheckpointName: String?
    let selectedPerformanceName: String?
    let onMove: () -> Void
    let onInsertBefore: () -> Void
    let onInsertAfter: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Form {
            Section {
                Picker("地点の種類", selection: $pointType) {
                    ForEach(validTypes, id: \.self) { type in
                        Text(type.text).tag(type)
                    }
                }
                .pickerStyle(.menu)

                switch pointType {
                case .checkpoint:
                    if #available(iOS 18.0, *) {
                        Picker("交差点の種類", selection: $point.checkpointId) {
                            ForEach(checkpoints) { checkpoint in
                                Text(checkpoint.name).tag(Optional(checkpoint.id))
                            }
                        } currentValueLabel: {
                            Text(selectedCheckpointName ?? "未選択")
                        }
                        .pickerStyle(.menu)
                    } else {
                        Picker("交差点の種類", selection: $point.checkpointId) {
                            ForEach(checkpoints) { checkpoint in
                                Text(checkpoint.name).tag(Optional(checkpoint.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    TimePicker("時刻を選択", selection: $point.time.unwrapped)
                        .datePickerStyle(.compact)
                case .performance:
                    if #available(iOS 18.0, *) {
                        Picker("余興の種類", selection: $point.performanceId) {
                            ForEach(performances) { performance in
                                Text(performance.name).tag(Optional(performance.id))
                            }
                        } currentValueLabel: {
                            Text(selectedPerformanceName ?? "未選択")
                        }
                        .pickerStyle(.menu)
                    } else {
                        Picker("余興の種類", selection: $point.performanceId) {
                            ForEach(performances) { performance in
                                Text(performance.name).tag(Optional(performance.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Toggle("時刻を設定", isOn: $point.time.toggle)
                    if point.time != nil {
                        TimePicker("時刻を選択", selection: $point.time.unwrapped)
                            .datePickerStyle(.compact)
                    }
                case .start, .end, .rest:
                    TimePicker("時刻を選択", selection: $point.time.unwrapped)
                        .datePickerStyle(.compact)
                case .none:
                    EmptyView()
                }
            }

            Section {
                Toggle("ここから色を変更", isOn: $point.isBoundary)
            } footer: {
                Text("経路が重なって見にくい場合は、この地点から表示色を変更できます。")
            }

            Section {
                Button("この地点を移動", systemImage: "arrow.up.right", action: onMove)
                Button("この地点の前に新しい地点を挿入", systemImage: "arrow.turn.left.up", action: onInsertBefore)
                Button("この地点の後に新しい地点を挿入", systemImage: "arrow.turn.right.up", action: onInsertAfter)
            } footer: {
                Text("ボタンを押した後、地図を長押しして地点の移動・挿入ができます。")
            }
            Section {
                Button("この地点を削除", systemImage: "trash", action: onDelete)
                    .foregroundStyle(.red)
            }
        }
    }
}

fileprivate extension PointEditFeature.PointType {
    var text: String {
        switch self {
        case .checkpoint:
            return "交差点"
        case .performance:
            return "余興"
        case .start:
            return "出発"
        case .end:
            return "到着"
        case .rest:
            return "休憩"
        case .none:
            return "なし"
        }
    }
}
