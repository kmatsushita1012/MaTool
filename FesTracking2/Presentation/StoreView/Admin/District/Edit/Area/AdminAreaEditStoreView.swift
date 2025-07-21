//
//  AdminAreaView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/16.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

struct AdminAreaView:View {
    @Bindable var store: StoreOf<AdminAreaEdit>
    
    var body: some View {
        ZStack {
            AdminDistrictMap(
                coordinates: store.coordinates,
                isShownPolygon: true,
                region: $store.region,
                onMapLongPress: { coordinate in store.send(.mapTapped(coordinate))}
            )
            .edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        store.send(.undoTapped)
                    }) {
                        Image(systemName: "arrow.uturn.backward")
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
        .navigationTitle("町域")
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
