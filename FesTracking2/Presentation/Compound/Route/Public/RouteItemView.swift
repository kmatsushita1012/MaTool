//
//  DistrictSummaryView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/19.
//

import ComposableArchitecture
import SwiftUI

struct RouteItemView: View {
    let item: RouteSummary
    let onTap: (RouteSummary) -> Void
    
    var body: some View {
        VStack {
            Text(item.districtId)
            Text("\(item.date.year) \(item.date.month) \(item.date.day)")
            Text(item.title)
        }.onTapGesture(perform: { _ in onTap(item)})
        
    }
}

#Preview {
    DistrictItemView(item: DistrictSummary.sample, onTap: { id in print("onTap ${id}")})
}
