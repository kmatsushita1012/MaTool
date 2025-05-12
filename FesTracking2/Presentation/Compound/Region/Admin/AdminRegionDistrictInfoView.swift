//
//  AdminRegionDistrictInfoView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture

struct AdminRegionDistrictInfoView: View {
    let store: StoreOf<AdminRegionDistrictInfoFeature>
    
    var body: some View {
        NavigationStack{
            VStack{
                Text("AdminRegionDistrict")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        store.send(.dismissTapped)
                    }) {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                    .padding(.horizontal, 8)
                }
                ToolbarItem(placement: .principal) {
                    Text(store.district.name)
                        .bold()
                }
            }
        }
    }
}
