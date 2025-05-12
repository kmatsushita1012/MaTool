//
//  AdminRegionDistrictCreateView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture

struct AdminRegionDistrictCreateView: View {
    
    @Bindable var store: StoreOf<AdminRegionDistrictCreateFeature>
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("AdminRegionDistrictCreateView")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        store.send(.cancelTapped)
                    }
                    .padding(8)
                }
                ToolbarItem(placement: .principal) {
                    Text("新規作成")
                        .bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button{
                        store.send(.saveTapped)
                    } label: {
                        Text("保存")
                            .bold()
                    }
                    .padding(8)
                }
            }
            
        }
    }
}
