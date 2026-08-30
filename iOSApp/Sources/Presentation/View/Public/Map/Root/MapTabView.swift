import ComposableArchitecture
import Shared
import SwiftUI

struct MapTabScreen: View {
    @Perception.Bindable var store: StoreOf<MapTabFeature>

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                MapTabContentView(
                    festivals: store.festivals,
                    selectedFestivalID: store.selectedFestival?.id,
                    isLinked: store.publicSelection.isLinked,
                    isLoading: store.isLoading,
                    isFestivalListLoading: store.isFestivalListLoading,
                    onFestivalSelected: { store.send(.festivalSelected($0)) }
                )
                    .navigationDestination(
                        item: $store.scope(
                            state: \.destination,
                            action: \.destination
                        )
                    ) { destination in
                        switch destination.case {
                        case .map(let store):
                            PublicMapView(store: store)
                        }
                    }
                    .alert($store.scope(state: \.alert, action: \.alert))
            }
        }
    }

}

struct MapTabContentView: View {
    let festivals: [Festival]
    let selectedFestivalID: Festival.ID?
    let isLinked: Bool
    let isLoading: Bool
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
                            .overlay {
                                if isLoading && selectedFestivalID == festival.id {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                        }
                        .disabled(isLoading || isFestivalListLoading)
                    }
                }

                if isFestivalListLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(isLinked ? "祭を選択" : "地図")
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
