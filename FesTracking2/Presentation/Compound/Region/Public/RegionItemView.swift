//
//  DistrictSummaryView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/19.
//

import ComposableArchitecture
import SwiftUI

struct RegionItemView: View {
    let item: Region
    let onTap: (Region) -> Void
    
    var body: some View {
        
        VStack {
            Text(item.name)
        }.onTapGesture(perform: { _ in onTap(item)})
        
    }
}

#Preview {
    RegionItemView(item: Region.sample, onTap: { id in print("onTap ${id}")})
}
