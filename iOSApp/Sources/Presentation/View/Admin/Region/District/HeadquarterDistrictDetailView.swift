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
                    RouteSlotView(pair){
                        store.send(.routeSelected(pair))
                    }
                }
            }
            Section {
                Button(action: {
                    store.send(.batchExportTapped)
                }) {
                    Text("経路図一括出力")
                }
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
        .alert($store.scope(state: \.alert, action: \.alert))
        .loadingOverlay(store.isLoading)
    }
}
