//
//  FestivalInfoView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/29.
//

import SwiftUI
import ComposableArchitecture
import MapKit
import Shared

struct FestivalInfoScreen: View {
    @Perception.Bindable var store: StoreOf<FestivalInfoFeature>
    let isDistrictLoading: Bool

    init(
        store: StoreOf<FestivalInfoFeature>,
        isDistrictLoading: Bool = false
    ) {
        self.store = store
        self.isDistrictLoading = isDistrictLoading
    }
    
    var body: some View {
        WithPerceptionTracking {
            FestivalInfoContentView(
                festival: store.festival,
                districts: store.districts,
                isDistrictLoading: isDistrictLoading,
                region: $store.region,
                onDistrictSelected: { store.send(.districtSelected($0)) }
            )
            .navigationDestination(
                item: $store.scope(state: \.destination, action: \.destination)
            ) { destination in
                switch destination.case {
                case .district(let store):
                    DistrictInfoScreen(store: store)
                }
            }
        }
    }
}

typealias FestivalInfoView = FestivalInfoScreen

struct FestivalInfoContentView: View {
    let festival: Festival
    let districts: [District]
    let isDistrictLoading: Bool
    @Binding var region: MKCoordinateRegion?
    let onDistrictSelected: (District) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Color.clear
                    .frame(height: 220)

                if !festival.prefecture.isEmpty || !festival.city.isEmpty {
                    InfoMaterialContainer {
                        Text("\(festival.prefecture)\(festival.city)")
                            .font(.title3.weight(.semibold))
                    }
                }

                if let description = festival.description {
                    InfoMaterialContainer {
                        ExpandableTextView(text: description)
                    }
                }

                InfoMaterialContainer {
                    InfoMapView(
                        base: festival.base,
                        baseTitle: festival.subname,
                        area: [],
                        region: $region
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(height: 384)
                }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .modifier(SoftTopScrollEdgeEffectModifier())
        .background {
            InfoImageBackgroundView(
                lightPath: festival.image.light,
                darkPath: festival.image.dark
            )
            .ignoresSafeArea()
        }
        .navigationTitle(festival.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(districts) { district in
                        Button {
                            onDistrictSelected(district)
                        } label: {
                            Text(district.name)
                        }
                    }
                } label: {
                    Text("町を選択")
                }
                .overlay(alignment: .trailing) {
                    if isDistrictLoading {
                        ProgressView()
                    }
                }
                .disabled(isDistrictLoading || districts.isEmpty)
            }
        }
    }
}
