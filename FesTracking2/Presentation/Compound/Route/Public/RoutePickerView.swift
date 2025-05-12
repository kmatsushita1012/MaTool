//
//  RoutePickerView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/03.
//

import SwiftUI
import ComposableArchitecture

struct RoutePickerView: View {
    @Bindable var store: StoreOf<PickerFeature<RouteSummary>>
    
    var body: some View {
        VStack(spacing: 8)  {
            ToggleSelectedItem(title: store.selected.text, isExpanded: $store.isExpanded)
                .padding(8)
                .background(.white)
                .cornerRadius(8)
                .shadow(radius: 3)
            if store.isExpanded {
                ForEach(store.others) { item in
                    ToggleOptionItem(title: item.text, onTap: { store.send(.selected(item))})
                        .padding(8)
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(8)
                        .padding(.top, 4)
                        .shadow(radius: 3)
                }
            }
        }
        .padding()
    }
}


