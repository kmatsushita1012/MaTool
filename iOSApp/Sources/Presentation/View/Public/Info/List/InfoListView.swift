//
//  InfoListView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/08.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl
import Shared

struct InfoListScreen: View {
    @SwiftUI.Bindable var store: StoreOf<InfoListFeature>

    var body: some View {
        WithPerceptionTracking {
            InfoListContentView(
                festivalName: store.festival.name,
                districts: store.districts,
                onDismissTapped: { store.send(.dismissTapped) },
                onFestivalTapped: { store.send(.festivalTapped) },
                onDistrictTapped: { store.send(.districtTapped($0)) }
            )
            .navigationDestination(item: $store.scope(state: \.destination?.district, action: \.destination.district)) { store in
                WithPerceptionTracking {
                    DistrictInfoView(store: store)
                }
            }
            .navigationDestination(item: $store.scope(state: \.destination?.festival, action: \.destination.festival)) { store in
                WithPerceptionTracking {
                    FestivalInfoView(store: store)
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .dismissible(backButton: false)
            .dismissOnChange(of: store.isDismissed)
            .loadingOverlay(store.isLoading)
        }
    }
}

typealias InfoListView = InfoListScreen

struct InfoListContentView: View {
    let festivalName: String
    let districts: [District]
    let onDismissTapped: () -> Void
    let onFestivalTapped: () -> Void
    let onDistrictTapped: (District) -> Void

    var body: some View {
        VStack {
            TitleView(
                text: "町を見てみよう",
                image: "InfoBackground"
            ) {
                onDismissTapped()
            }
            .ignoresSafeArea(edges: .top)

            InfoListFestivalItemView(text: festivalName)
                .onTapGesture(perform: onFestivalTapped)
                .padding(.horizontal, 96)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(districts) { district in
                        InfoListDistrictItemView(text: district.name)
                            .onTapGesture {
                                onDistrictTapped(district)
                            }
                    }
                }
                .padding(.horizontal, 64)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            .mask(InfoListMaskView())

            InfoListFestivalItemView(text: "　")
                .padding(.horizontal, 96)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .preferredColorScheme(.light)
    }
}

private struct InfoListFestivalItemView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title)
            .foregroundColor(.primary)
            .stroke(color: .white, width: 2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.info)
            .cornerRadius(8)
    }
}

private struct InfoListDistrictItemView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title2)
            .foregroundColor(.primary)
            .stroke(color: .white, width: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.info.opacity(0.6))
            .cornerRadius(8)
    }
}

private struct InfoListMaskView: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .primary, location: 0.05),
                .init(color: .primary, location: 0.95),
                .init(color: .clear, location: 1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    InfoListContentView(
        festivalName: "",
        districts: [],
        onDismissTapped: {},
        onFestivalTapped: {},
        onDistrictTapped: { _ in }
    )
}
