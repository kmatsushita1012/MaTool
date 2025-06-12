//
//  AdminRegionView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/09.
//

import SwiftUI
import ComposableArchitecture

struct AdminRegionView: View {
    @Bindable var store: StoreOf<AdminRegionTop>
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationItem(
                        title: "祭典情報",
                        iconName: "info.circle" ,
                        onTap: { store.send(.onEdit) })
                }
                Section(header: Text("参加町")){
                    List(store.districts) { district in
                        NavigationItem(
                            title: district.name,
                            onTap: {
                                store.send(.onDistrictInfo(district))
                            }
                        )
                    }
                    Button(action: {
                        store.send(.onCreateDistrict)
                    }) {
                        Label("追加", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                Section {
                    Text("ログアウト")
                        .foregroundColor(.red)
                        .onTapGesture {
                            store.send(.signOutTapped)
                        }
                }
            }
            .navigationTitle(
                "\(store.region.name) \(store.region.subname)"
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        store.send(.homeTapped)
                    }) {
                        Image(systemName: "house")
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 8)
                }
            }
            .fullScreenCover(
                item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
            ) { store in
                AdminRegionEditView(store: store)
            }
            .fullScreenCover(
                item: $store.scope(state: \.destination?.districtInfo, action: \.destination.districtInfo)
            ) { store in
                AdminRegionDistrictInfoView(store: store)
            }
            .fullScreenCover(
                item: $store.scope(state: \.destination?.districtCreate, action: \.destination.districtCreate)
            ) { store in
                AdminRegionCreateDistrictView(store: store)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
