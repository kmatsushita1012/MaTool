//
//  AdminBaseView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/16.
//

import SwiftUI
import ComposableArchitecture

struct AdminBaseView:View {
    let store: StoreOf<BaseAdminFeature>
    
    var body: some View {
        NavigationStack{
            ZStack {
                AdminDistrictMap(
                    coordinates: store.coordinate.map { [$0] },
                    isShownPolygon: false,
                    onMapLongPress: { coordinate in store.send(.mapTapped(coordinate))},
                )
                .edgesIgnoringSafeArea(.all)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        store.send(.cancelButtonTapped)
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .padding(.horizontal, 8)
                }
                ToolbarItem(placement: .principal) {
                    Text("会所位置編集")
                        .bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button{
                        store.send(.doneButtonTapped)
                    } label: {
                        Text("完了")
                            .bold()
                    }
                    .padding(.horizontal, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
}
