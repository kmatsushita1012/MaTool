//
//  PeriodArchivesView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/08.
//

import SwiftUI
import ComposableArchitecture
import Shared

@available(iOS 17.0, *)
struct PeriodArchivesScreen: View {
    @SwiftUI.Bindable var store: StoreOf<PeriodArchivesFeature>
    
    var body: some View {
        PeriodArchivesContentView(
            year: store.year,
            periods: store.periods,
            onPeriodTapped: { store.send(.periodTapped($0)) }
        )
            .navigationDestination(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) {
                PeriodEditView(store: $0)
            }
    }
}

@available(iOS 17.0, *)
typealias PeriodArchivesView = PeriodArchivesScreen

@available(iOS 17.0, *)
struct PeriodArchivesContentView: View {
    let year: Int
    let periods: [Period]
    let onPeriodTapped: (Period) -> Void

    var body: some View {
        Form {
            Section("\(String(year))年") {
                ForEach(periods) { period in
                    NavigationItemView(title: period.text) {
                        onPeriodTapped(period)
                    }
                }
            }
        }
        .navigationTitle("過去の日程")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    PeriodArchivesContentView(year: 2026, periods: [], onPeriodTapped: { _ in })
}
