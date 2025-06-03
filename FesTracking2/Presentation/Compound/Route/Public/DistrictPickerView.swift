//
//  DistrictPickerView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/03.
//

import SwiftUI
import ComposableArchitecture

struct DistrictPickerView: View {
    let store: StoreOf<PickerFeature<RouteFeature.Content>>
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing:8){
                ForEach(store.items, id: \.self) { item in
                    if item == store.selected{
                        Button(action: {}) {
                            Text(item.text)
                                .foregroundColor(.primary)
                        }
                        .frame(minWidth: 48)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(.white)
                        .clipShape(.rect(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 16
                        ))
                    }else {
                        Button(action: {
                            store.send(.selected(item))
                        }) {
                            Text(item.text)
                        }
                        .frame(minWidth: 48)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(.clear)
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .background(Color.customLightRed)
    }
}
