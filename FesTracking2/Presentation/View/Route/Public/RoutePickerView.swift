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
            if let selected = store.selected {
                ToggleSelectedItem(title: selected.text(format:"m/d T"), isExpanded: $store.isExpanded)
                    .padding(8)
                    .background(.white)
                    .cornerRadius(8)
                    .shadow(radius: 3)
            }
            if store.isExpanded {
                ForEach(store.others) { route in
                    ToggleOptionItem(title: route.text(format:"m/d T"), onTap: { store.send(.selected(route))})
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


