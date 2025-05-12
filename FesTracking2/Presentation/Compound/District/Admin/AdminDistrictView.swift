//
//  AdminDistrictView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

struct AdminDistrictView: View{
    @Bindable var store: StoreOf<AdminDistrictFeature>
    
    var body: some View {
        NavigationStack {
            Form{
                Section{
                    NavigationItem(
                        title: "地区情報",
                        iconName: "info.circle" ,
                        onTap: { store.send(.onInfo) })
                    NavigationItem(
                        title: "位置情報配信",
                        iconName: "mappin.and.ellipse",
                        onTap: {
                            store.send(.onLocation)
                        }
                    )
                }
                Section(header: Text("経路")){
                    List(store.routes) { route in
                        NavigationItem(
                            title: "\(route.date.text(year: false)) \(route.title)",
                            onTap: {
                                store.send(.onRouteEdit(route))
                            }
                        )
                    }
                    Button(action: {
                        store.send(.onRouteAdd)
                    }) {
                        Label("追加", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                Section {
                    Text("ログアウト")
                        .foregroundColor(.red)
                        .onTapGesture {
                            store.send(.onSignOut)
                        }
                }
            }
            .navigationTitle(
                store.district.name
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
            .fullScreenCover(item: $store.scope(state: \.destination?.info, action: \.destination.info)) { store in
                AdminDistrictInfoView(store: store)
                    .interactiveDismissDisabled(true)
                    .navigationBarBackButtonHidden(true)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.location, action: \.destination.location)) { store in
                LocationAdminView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.route, action: \.destination.route)) { store in
                AdminRouteInfoView(store: store)
                    .interactiveDismissDisabled(true)
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}
