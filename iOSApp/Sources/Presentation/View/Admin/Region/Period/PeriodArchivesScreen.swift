//
//  PeriodArchivesScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/12/08.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct PeriodArchivesScreen: View {
    @SwiftUI.Bindable var store: StoreOf<PeriodArchivesFeature>

    var body: some View {
        WithPerceptionTracking {
            PeriodArchivesContentView(
                year: store.year,
                periods: store.periods,
                onPeriodTapped: { store.send(.periodTapped($0)) }
            )
            .navigationTitle("過去の日程")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .edit(let store):
                    PeriodEditScreen(store: store)
                }
            }
        }
    }
}
