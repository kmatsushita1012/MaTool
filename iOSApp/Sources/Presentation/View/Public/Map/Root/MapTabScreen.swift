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
                    PublicMapScreen(store: store)
                        }
                    }
                    .alert($store.scope(state: \.alert, action: \.alert))
            }
        }
    }

}
