//
//  AdminBaseView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/16.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

struct AdminBaseView:View {
    @Bindable var store: StoreOf<AdminBaseEdit>
    
    var body: some View {
        ZStack {
            AdminDistrictMap(
                coordinates: store.coordinate.map { [$0] },
                isShownPolygon: false,
                region: $store.region,
                onMapLongPress: { coordinate in store.send(.mapTapped(coordinate))}
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        store.send(.clearTapped)
                    }) {
                        Image(systemName: "eraser")
                            .font(.title2)
                            .padding(12)
                            .background(Color(.systemBackground).opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .navigationTitle("会所位置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    store.send(.dismissTapped)
                } label: {
                    HStack {
                        Text("キャンセル")
                    }
                    .padding(8)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button{
                    store.send(.doneTapped)
                } label: {
                    Text("完了")
                        .bold()
                }
                .padding(.horizontal, 8)
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .dismissible(backButton: false, edgeSwipe: false)
    }
}
