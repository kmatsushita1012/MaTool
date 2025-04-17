//
//  DistrictSummaryView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/19.
//

import ComposableArchitecture
import SwiftUI

struct DistrictsDetailView: View {
    let store: StoreOf<DistrictDetailFeature>
    
    var body: some View {
        VStack {
            store.item.viewWhen(
                loading: {
                    ProgressView()
                },
                success: { item in
                    Text(item.name)
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


