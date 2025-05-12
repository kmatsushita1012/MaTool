//
//  AdminRegionView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/09.
//

import SwiftUI
import ComposableArchitecture

struct AdminRegionView: View {
    let store: StoreOf<AdminRegionFeature>
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("region")
            }
            .navigationTitle(
                store.region.name
            )
        }
    }
}
