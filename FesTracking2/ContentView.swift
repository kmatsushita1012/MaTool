//
//  ContentView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/02/28.
//

import SwiftUI
import SwiftData
import ComposableArchitecture

struct ContentView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        AdminDistrictView(store:
            Store(initialState:
                    AdminDistrictFeature.State(district: PublicDistrict.sample, routes: [RouteSummary.sample]),
              reducer:
                    { AdminDistrictFeature() }
             )
        )

    }
}

//
//#Preview {
//    ContentView(store: Store(initialState:AuthFeature.State()){ AuthFeature()._printChanges()})
//}
