//
//  HeadquarterDistrictDetailContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
struct HeadquarterDistrictDetailContentView: View {
    @Binding var district: District
    @Binding var displayedOrder: Int
    let routes: [RouteSlot]
    let routeDrafts: [Route.ID: RouteDraft]
    let isEditable: Bool
    let isSubmissionExportLoading: Bool
    let isTableExportLoading: Bool
    let onRouteSelected: (RouteSlot) -> Void
    let onResetDrafts: () -> Void
    let onSubmissionExport: () -> Void
    let onTableExport: () -> Void
    let onReissue: () -> Void

    var body: some View {
        List {
            Section {
                LabeledContent("順序") {
                    TextField("（1始まりの整数）", value: $displayedOrder, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("ブロック") {
                    TextField("（任意）", text: $district.group.nonOptional)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                Toggle("ルート更新を停止", isOn: $district.isEditable.inverted)
            } footer: {
                Text("編集する際は右上の「編集」ボタンを押してください。")
            }
            .disabled(!isEditable)

            Section(header: Text("ルート")) {
                ForEach(routes) { pair in
                    let statusText: String? = {
                        guard let route = pair.route, routeDrafts[route.id] != nil else { return nil }
                        return "修正済"
                    }()
                    RouteSlotView(pair, statusText: statusText) {
                        onRouteSelected(pair)
                    }
                }
                Button("修正をリセット", action: onResetDrafts)
                    .disabled(routeDrafts.isEmpty)
            }
            Section {
                HeadquarterExportButton(
                    title: "提出資料出力",
                    showsProgress: isSubmissionExportLoading,
                    isDisabled: isSubmissionExportLoading || isTableExportLoading,
                    action: onSubmissionExport
                )
                HeadquarterExportButton(
                    title: "行動表出力",
                    showsProgress: isTableExportLoading,
                    isDisabled: isSubmissionExportLoading || isTableExportLoading,
                    action: onTableExport
                )
            }
            Section {
                Button(role: .destructive, action: onReissue) {
                    Text("アカウント再発行")
                }
            } footer: {
                Text("町データは保持されます。再発行後は入力したメールアドレスでアカウント再登録が必要です。")
            }
        }
    }
}

@available(iOS 17.0, *)
private struct HeadquarterExportButton: View {
    let title: String
    let showsProgress: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .trailing) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .disabled(isDisabled)
    }
}
