import iOSShared
import Application
import View
//
//  HeadquarterDistrictListScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct HeadquarterDistrictListScreen: View {
    @SwiftUI.Bindable var store: StoreOf<HeadquarterDistrictListFeature>

    var body: some View {
        WithPerceptionTracking {
            let listContent = HeadquarterDistrictListContentView(
                isReordering: store.isReordering,
                searchText: $store.searchText,
                draftDistricts: store.draftDistricts,
                districts: store.districts,
                filteredDistricts: store.filteredDistricts,
                isLoading: store.isLoading,
                isReorderDisabled: store.isReorderDisabled,
                isExportLoading: store.isExportLoading,
                onDistrictSelected: { store.send(.selected($0)) },
                onDistrictMoved: { store.send(.districtMoved(from: $0, to: $1)) },
                onBatchExport: { store.send(.batchExportTapped) },
                onReorder: { store.send(.reorderTapped) },
                onCreate: { store.send(.createTapped) }
            )
            let searchableContent = listContent
            .searchable(text: $store.searchText, prompt: "町名で検索")
            let presentedContent = searchableContent
                .sheet(item: $store.folder, content: shareSheet)
                .navigationDestination(item: $store.scope(state: \.destination, action: \.destination), destination: destinationView)
                .fullScreenCover(item: $store.scope(state: \.editDestination, action: \.editDestination), content: editDestinationView)
                .alert($store.scope(state: \.alert, action: \.alert))
            presentedContent
                .environment(\.editMode, .constant(store.isReordering ? .active : .inactive))
        }
    }

    @ViewBuilder
    private func destinationView(
        _ destination: StoreOf<HeadquarterDistrictListFeature.Destination>
    ) -> some View {
        switch destination.case {
        case .detail(let store):
            HeadquarterDistrictDetailScreen(store: store)
        }
    }

    @ViewBuilder
    private func editDestinationView(
        _ destination: StoreOf<HeadquarterDistrictListFeature.EditDestination>
    ) -> some View {
        switch destination.case {
        case .create(let store):
            DistrictCreateScreen(store: store)
        }
    }

    private func shareSheet(_ folder: ExportedFolder) -> some View {
        ShareSheet<URL>(items: folder.files)
    }

}
