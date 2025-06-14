//
//  AdminAreaView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/16.
//

import SwiftUI
import ComposableArchitecture

struct AdminAreaView:View {
    @Bindable var store: StoreOf<AdminAreaEdit>
    
    var body: some View {
        NavigationStack{
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.send(.dismissTapped)
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("キャンセル")
                        }
                        .padding(8)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("町域編集")
                        .bold()
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
}
