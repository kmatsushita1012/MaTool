//
//  AppView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/21.
//

import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    @Perception.Bindable var store: StoreOf<HomeFeature>
    
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
                                    if #available(iOS 17.0, *){
                                        card("AdminCard")
                                            .frame(height: geometry.size.height * 3 / 5 )
                                            .onTapGesture {
                                                store.send(.adminTapped)
                                            }
                                    } else {
                                        disabledCard("管理者用ページはお使いの端末（iOS 16）では利用できません")
                                            .frame(height: geometry.size.height * 3 / 5 )
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
                    .background (
                        Image("HomeBackground")
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea(edges: [.top])
                    )
                    .navigationDestination(item: $store.scope(state: \.destination?.map, action: \.destination.map)) { store in
                        PublicMapView(store: store)
                    }
                    .navigationDestination(item: $store.scope(state: \.destination?.info, action: \.destination.info)) { store in
                        InfoListView(store: store)
                    }
                    .navigationDestination(item: $store.scope(state: \.destination?.login, action: \.destination.login)) { store in
                        if #available(iOS 17.0, *){
                            LoginView(store: store)
                        } else {
                            EmptyView()
                        }
                    }
                    .navigationDestination(item: $store.scope(state: \.destination?.adminDistrict, action: \.destination.adminDistrict)) { store in
                        if #available(iOS 17.0, *){
                            DistrictDashboardView(store: store)
                        } else {
                            EmptyView()
                        }
                    }
                    .navigationDestination(item: $store.scope(state: \.destination?.adminFestival, action: \.destination.adminFestival)) { store in
                        if #available(iOS 17.0, *){
                            FestivalDashboardView(store: store)
                        } else {
                            EmptyView()
                        }
                    }
                    .navigationDestination(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
                        SettingsView(store: store)
                    }
                    .alert($store.scope(state: \.alert, action: \.alert))
                    .loadingOverlay(store.isLoading)
                )
                .sheet(item: $store.status) { status in
                    WithPerceptionTracking {
                        AppStatusModal(status)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func card(_ imageName: String, priority: Double = 0) -> some View {
        GeometryReader { geometry in
            WithPerceptionTracking{
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    func disabledCard(_ message: String, priority: Double = 0) -> some View {
        GeometryReader { geometry in
            WithPerceptionTracking{
                Text(message)
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
}
