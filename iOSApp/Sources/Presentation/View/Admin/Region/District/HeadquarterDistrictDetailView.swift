//
//  HeadquarterDistrictDetailView.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/24.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct HeadquarterDistrictDetailView: View {
    @SwiftUI.Bindable var store: StoreOf<HeadquarterDistrictDetailFeature>
    
    var body: some View {
        List {
            Section {
                LabeledContent("順序") {
                    TextField("（整数）" ,value: $store.district.order, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("ブロック") {
                    TextField("（任意）" , text: $store.district.group.nonOptional)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                Toggle("ルート更新を停止", isOn: $store.district.isEditable.inverted)

            } footer: {
                Text("編集する際は右上の「編集」ボタンを押してください。")
            }
            .disabled(!store.isEditable)
            Section(header: Text("ルート")) {
                ForEach(store.routes) { pair in
                    let statusText: String? = {
                        guard let route = pair.route,
                              store.routeDrafts[route.id] != nil else { return nil }
                        return "修正済"
                    }()
                    RouteSlotView(
                        pair,
                        statusText: statusText
                    ) {
                        store.send(.routeSelected(pair))
                    }
                }
                Button("修正をリセット") {
                    store.send(.resetDraftsTapped)
                }
                .disabled(store.routeDrafts.isEmpty)
            }
            Section {
                loadingButton(
                    "提出資料出力",
                    showsProgress: store.isSubmissionExportLoading,
                    isDisabled: store.isSubmissionExportLoading || store.isTableExportLoading
                ) {
                    store.send(.batchExportTapped)
                }
                loadingButton(
                    "行動表出力",
                    showsProgress: store.isTableExportLoading,
                    isDisabled: store.isSubmissionExportLoading || store.isTableExportLoading
                ) {
                    store.send(.tableExportTapped)
                }
            }
            Section {
                Button(role: .destructive) {
                    store.send(.reissueTapped)
                } label: {
                    Text("アカウント再発行")
                }
            } footer: {
                Text("町データは保持されます。再発行後は入力したメールアドレスでアカウント再登録が必要です。")
            }
        }
        .navigationTitle(store.district.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.isEditable {
                ToolbarSaveButton {
                    store.send(.editTapped)
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button("編集"){
                        store.send(.editTapped)
                    }
                }
            }
            
        }
        .sheet(item: $store.url){ url in
            ShareSheet(item: url)
        }
        .navigationDestination(
            item: $store.scope(state: \.destination?.route, action: \.destination.route)
        ) { store in
            RouteEditView(store: store)
        }
        .navigationDestination(
            item: $store.scope(state: \.destination?.reissue, action: \.destination.reissue)
        ) { store in
            DistrictReissueView(store: store)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .loadingOverlay(store.isLoading && !store.isExportLoading)
    }
}

@available(iOS 17.0, *)
private extension HeadquarterDistrictDetailView {
    @ViewBuilder
    func loadingButton(
        _ title: String,
        showsProgress: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
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
