//
//  InfoListView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/08.
//

import SwiftUI
import ComposableArchitecture
import Shared

struct InfoListScreen: View {
    @Perception.Bindable var store: StoreOf<InfoListFeature>
    
    var body: some View {
        WithPerceptionTracking{
            NavigationStack {
                InfoListContentView(
                    festivals: store.festivals,
                    selectedFestivalID: store.selectedFestival?.id,
                    isLinked: store.publicSelection.isLinked,
                    isFestivalListLoading: store.isFestivalListLoading,
                    onFestivalSelected: { store.send(.festivalSelected($0)) }
                )
                .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                    switch destination.case {
                    case .festival(let store):
                        FestivalInfoScreen(store: store, isDistrictLoading: self.store.isLoading)
                    }
                }
                .alert($store.scope(state: \.alert, action: \.alert))
            }
        }
    }
}

typealias InfoListView = InfoListScreen

struct InfoListContentView: View {
    let festivals: [Festival]
    let selectedFestivalID: Festival.ID?
    let isLinked: Bool
    let isFestivalListLoading: Bool
    let onFestivalSelected: (Festival) -> Void

    var body: some View {
        List {
            festivalSection {
                if festivals.isEmpty && isFestivalListLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack {
                            Text("祭典名")
                            Spacer()
                        }
                        .redacted(reason: .placeholder)
                    }
                } else {
                    ForEach(festivals) { festival in
                        Button {
                            onFestivalSelected(festival)
                        } label: {
                            HStack {
                                Text(festival.name)
                                Spacer()
                                if selectedFestivalID == festival.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .disabled(isFestivalListLoading)
                    }
                }

                if isFestivalListLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(isLinked ? "祭を選択" : "紹介")
    }

    @ViewBuilder
    private func festivalSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if isLinked {
            content()
        } else {
            Section("祭を選択", content: content)
        }
    }
}
