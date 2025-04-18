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
    let store: StoreOf<AuthFeature>
    
    init(store: StoreOf<AuthFeature>) {
        self.store = store
        print("ContentView")
    }

    var body: some View {
        LocationAdminView(store:
            Store(initialState:
                    LocationAdminFeature.State(id: "johoku"),
              reducer:
                    { LocationAdminFeature() }
             )
        )

    }
}

//
//#Preview {
//    ContentView(store: Store(initialState:AuthFeature.State()){ AuthFeature()._printChanges()})
//}
