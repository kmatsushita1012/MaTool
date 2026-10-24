//
//  HomeView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/21.
//

import SwiftUI
import ComposableArchitecture

struct HomeScreen: View {
    @SwiftUI.Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        WithPerceptionTracking {
            HomeContentView(
                onMapTapped: { store.send(.mapTapped) },
                onInfoTapped: { store.send(.infoTapped) },
                onSettingsTapped: { store.send(.settingsTapped) },
                onAdminTapped: { store.send(.adminTapped) }
            )
            .modifier(HomeDestinations(store: store))
            .alert($store.scope(state: \.alert, action: \.alert))
            .loadingOverlay(store.isLoading)
        }
    }
}

typealias HomeView = HomeScreen

private struct HomeDestinations: ViewModifier {
    @SwiftUI.Bindable var store: StoreOf<HomeFeature>

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $store.scope(state: \.destination?.map, action: \.destination.map)) { store in
                PublicMapView(store: store)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.info, action: \.destination.info)) { store in
                InfoListView(store: store)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.login, action: \.destination.login)) { store in
                if #available(iOS 17.0, *) {
                    LoginView(store: store)
                } else {
                    EmptyView()
                }
            }
            .navigationDestination(item: $store.scope(state: \.destination?.adminDistrict, action: \.destination.adminDistrict)) { store in
                if #available(iOS 17.0, *) {
                    DistrictDashboardView(store: store)
                } else {
                    EmptyView()
                }
            }
            .navigationDestination(item: $store.scope(state: \.destination?.adminFestival, action: \.destination.adminFestival)) { store in
                if #available(iOS 17.0, *) {
                    FestivalDashboardView(store: store)
                } else {
                    EmptyView()
                }
            }
            .navigationDestination(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
                SettingsView(store: store)
            }
    }
}

struct HomeContentView: View {
    let onMapTapped: () -> Void
    let onInfoTapped: () -> Void
    let onSettingsTapped: () -> Void
    let onAdminTapped: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HomeImageCard(imageName: "MapCard")
                .onTapGesture(perform: onMapTapped)
            HStack(spacing: 16) {
                GeometryReader { geometry in
                    VStack(spacing: 16) {
                        HomeImageCard(imageName: "InfoCard")
                            .frame(height: geometry.size.height * 3 / 5)
                            .onTapGesture(perform: onInfoTapped)

                        HomeImageCard(imageName: "ShopCard")
                            .frame(height: geometry.size.height * 2 / 5)
                    }
                }

                GeometryReader { geometry in
                    VStack(spacing: 16) {
                        HomeImageCard(imageName: "SettingsCard")
                            .frame(height: geometry.size.height * 2 / 5)
                            .onTapGesture(perform: onSettingsTapped)
                        if #available(iOS 17.0, *) {
                            HomeImageCard(imageName: "AdminCard")
                                .frame(height: geometry.size.height * 3 / 5)
                                .onTapGesture(perform: onAdminTapped)
                        } else {
                            HomeDisabledCard(message: "管理者用ページはお使いの端末（iOS 16）では利用できません")
                                .frame(height: geometry.size.height * 3 / 5)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background {
            Image("HomeBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea(edges: [.top])
        }
        .navigationTitle("トップ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .title) {
                Text("MaTool")
                    .foregroundStyle(.black)
                    .font(.custom("Kanit", size: 34))
                    .padding()
            }
        }
    }
}

private struct HomeImageCard: View {
    let imageName: String

    var body: some View {
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

private struct HomeDisabledCard: View {
    let message: String

    var body: some View {
        GeometryReader { geometry in
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

#Preview {
    HomeContentView(
        onMapTapped: {},
        onInfoTapped: {},
        onSettingsTapped: {},
        onAdminTapped: {}
    )
}
