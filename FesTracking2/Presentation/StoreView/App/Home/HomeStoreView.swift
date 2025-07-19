//
//  AppView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/21.
//

import SwiftUI
import ComposableArchitecture

struct HomeStoreView: View {
    @Bindable var store: StoreOf<Home>
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                card("MapCard")
                    .onTapGesture {
                        store.send(.mapTapped)
                    }
                HStack(spacing: 32)  {
                    VStack(spacing: 32)  {
                        card("InfoCard", priority: 2)
                            .onTapGesture{
                                store.send(.infoTapped)
                            }
                        card("ShopCard", priority: 1)
                            .onTapGesture{}
                        
                    }
                    VStack(spacing: 32)  {
                        card("SettingsCard", priority: 1)
                            .onTapGesture {
                                store.send(.settingsTapped)
                            }
                        card("AdminCard", priority: 2)
                            .onTapGesture {
                                store.send(.adminTapped)
                            }
                            .loadingOverlay(store.isAuthLoading)
                    }
                }
            }
            .padding(32)
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
            )
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.route, action: \.destination.route)) { store in
            PublicMapStoreView(store: store)
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.info, action: \.destination.info)) { store in
            InfoStoreView(store: store)
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.login, action: \.destination.login)) { store in
            LoginStoreView(store: store)
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.adminDistrict, action: \.destination.adminDistrict)) { store in
            AdminDistrictView(store: store)
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.adminRegion, action: \.destination.adminRegion)) { store in
            AdminRegionView(store: store)
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
            SettingsStoreView(store: store)
        }
        .sheet(isPresented: $store.shouldShowUpdateModal) {
            UpdateModalView()
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .loadingOverlay(store.isLoading)
        .onAppear(){
            store.send(.onAppear)
        }
    }
    
    @ViewBuilder
    func card(_ imageName: String, priority: Double = 0) -> some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .clipped()
            .cornerRadius(8)
            .layoutPriority(priority)
    }
}



