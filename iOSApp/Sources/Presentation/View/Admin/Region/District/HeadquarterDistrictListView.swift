//
//  HeadquarterDistrictListView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture
import Shared

@available(iOS 17.0, *)
struct HeadquarterDistrictListView: View {
    @SwiftUI.Bindable var store: StoreOf<HeadquarterDistrictListFeature>
    
    var body: some View {
        Form {
            Section {
                if store.isReordering {
                    ForEach(store.draftDistricts ?? store.districts.sorted()) { district in
                        Text(district.name)
                    }
                    .onMove { from, to in
                        store.send(.districtMoved(from: from, to: to))
                    }
                } else {
                    ForEach(store.filteredDistricts) { district in
                        NavigationItemView(
                            title: district.name,
                            onTap: {
                                store.send(.selected(district))
                            }
                        )
                    }
                }
            }
            #if DEBUG
            if !store.isReordering && store.searchText.isEmpty {
                Section {
                    loadingButton("提出資料出力", isLoading: store.isExportLoading) {
                        store.send(.batchExportTapped)
                    }
                }
            }
            #endif
        }
        .navigationTitle("参加町")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $store.searchText, prompt: "町名で検索", isEnabled: !store.isReordering)
        .sheet(item: $store.folder){ folder in
            ShareSheet(items: folder.files)
        }
        .navigationDestination(
            item: $store.scope(state: \.destination, action: \.destination)
        ) { destination in
            switch destination.case {
            case .detail(let store):
                HeadquarterDistrictDetailView(store: store)
            }
        }
        .fullScreenCover(
            item: $store.scope(state: \.editDestination, action: \.editDestination)
        ) { destination in
            switch destination.case {
            case .create(let store):
                DistrictCreateView(store: store)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.isReordering {
                    Button("完了") {
                        store.send(.reorderTapped)
                    }
                    .buttonStyle(.borderedProminent)
                    .overlay {
                        if store.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .disabled(store.isLoading)
                } else {
                    Button("並替") {
                        store.send(.reorderTapped)
                    }
                    .disabled(store.isReorderDisabled || store.isLoading)
                }
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer()
            }
            if !store.isReordering {
                ToolbarItem(placement: .topBarTrailing){
                    Button("追加") {
                        store.send(.createTapped)
                    }
                }
            }
        }
        .environment(\.editMode, .constant(store.isReordering ? .active : .inactive))
    }
}

@available(iOS 17.0, *)
private extension HeadquarterDistrictListView {
    @ViewBuilder
    func loadingButton(
        _ title: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .trailing) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .disabled(isLoading)
    }
}
