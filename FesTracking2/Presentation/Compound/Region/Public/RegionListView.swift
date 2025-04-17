//
//  DistrictSummaryView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/19.
//

import ComposableArchitecture
import SwiftUI

struct RegionListView: View {
    let store: StoreOf<RegionSummariesFeature>
    
    var body: some View {
        VStack {
            store.items.viewWhen(
                loading: {
                    ProgressView()
                },
                success: { items in
                    List(items) { item in
                        RegionItemView(item: item, onTap: { item in store.send(.selected(item))})
                    }
                },
                failure: { error in
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                }
            )
            
        }
        .padding()
        
    }
}


