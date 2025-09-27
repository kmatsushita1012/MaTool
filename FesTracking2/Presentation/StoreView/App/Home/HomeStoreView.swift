//
//  AppView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/21.
//

import SwiftUI
import ComposableArchitecture

struct HomeStoreView: View {
    @Perception.Bindable var store: StoreOf<Home>
    
    var body: some View {
        NavigationStack {
            WithPerceptionTracking{
                AnyView(
                    VStack(spacing: 16) {
                        card("MapCard")
                            .onTapGesture {
                                store.send(.mapTapped)
                            }
                        HStack(spacing: 16)  {
                            GeometryReader { geometry in
                                VStack(spacing: 16) {
                                    card("InfoCard", priority: 2)
                                        .frame(height: geometry.size.height * 3 / 5)
                                        .onTapGesture{
                                            store.send(.infoTapped)
                                        }
                                    
                                    card("ShopCard", priority: 1)
                                        .onTapGesture{
                                            print("Debug \(store.destination)")
                                        }
                                        .frame(height: geometry.size.height * 2 / 5)
                                }
                            }
                            
                            GeometryReader { geometry in
                                VStack(spacing: 16) {
                                    card("SettingsCard")
                                        .frame(height: geometry.size.height * 2 / 5)
                                        .onTapGesture {
                                            store.send(.settingsTapped)
                                        }
                                    
                                    card("AdminCard")
                                        .frame(height: geometry.size.height * 3 / 5 )
                                        .onTapGesture {
                                            store.send(.adminTapped)
                                        }
                                        .loadingOverlay(
                                            store.isAuthLoading,
                                            message: "スキップ"
                                        ) {
                                            store.send(.skipTapped)
                                        }
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("MaTool")
                                .font(.custom("Kanit", size: 34))
                                .padding()
                        }
                    }
                    .background(
                        Image("HomeBackground")
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea(edges: [.top])
                    )
                    .navigationDestination(item: $store.scope(state: \.destination?.map, action: \.destination.map)) { store in
                        WithPerceptionTracking{
                            PublicMapStoreView(store: store)
                        }
                    }
                    .navigationDestination(item: $store.scope(state: \.destination?.info, action: \.destination.info)) { store in
                        WithPerceptionTracking{
                            InfoStoreView(store: store)
                        }
                    }
                    .navigationDestination(item: $store.scope(state: \.destination?.login, action: \.destination.login)) { store in
                        if #available(iOS 17.0, *){
                            LoginStoreView(store: store)
                        } else {
                            EmptyView()
                        }

                    }
                    .navigationDestination(item: $store.scope(state: \.destination?.adminDistrict, action: \.destination.adminDistrict)) { store in
                        if #available(iOS 17.0, *){
                            AdminDistrictView(store: store)
                        } else {
                            EmptyView()
                        }

                    }
                    .navigationDestination(item: $store.scope(state: \.destination?.adminRegion, action: \.destination.adminRegion)) { store in
                        if #available(iOS 17.0, *){
                            AdminRegionView(store: store)
                        } else {
                            EmptyView()
                        }

                    }
                    .navigationDestination(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
                        WithPerceptionTracking {
                            SettingsStoreView(store: store)
                        }
                    }
                    .alert($store.scope(state: \.alert, action: \.alert))
                    .loadingOverlay(store.isLoading)
                )
            }
            .sheet(item: $store.status) { status in
                AppStatusModal(status)
            }
        }
    }
    
    @ViewBuilder
    func card(_ imageName: String, priority: Double = 0) -> some View {
        GeometryReader { geometry in
           Image(imageName)
               .resizable()
               .scaledToFill()
               .frame(width: geometry.size.width, height: geometry.size.height)
               .clipped()
               .cornerRadius(8)
       }
    }
}



