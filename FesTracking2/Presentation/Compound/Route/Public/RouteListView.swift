//
//  RouteDetailView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/06.
//

import ComposableArchitecture
import SwiftUI

struct RouteListView: View {
    let store: StoreOf<RouteSummariesFeature>
    
    var body: some View {
        VStack {
            store.items.viewWhen(
                loading: {
                    ProgressView()
                },
                success: { items in
                    List(items) { item in
                        RouteItemView(item: item, onTap: { item in store.send(.selected(item))})
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


