//
//  DistrictInfoView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/29.
//

import SwiftUI
import ComposableArchitecture
import MapKit
import Shared

struct DistrictInfoScreen: View {
    @Perception.Bindable var store: StoreOf<DistrictInfoFeature>
    
    var body: some View {
        WithPerceptionTracking{
            DistrictInfoContentView(
                district: store.district,
                performances: store.performances,
                region: $store.region
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.mapTapped)
                    } label: {
                        Label("現在地とルート", systemImage: "paperplane.fill")
                    }
                    .overlay {
                        if store.isLoading {
                            ProgressView()
                        }
                    }
                    .disabled(store.isLoading)
                }
            }
        }
    }
}

typealias DistrictInfoView = DistrictInfoScreen

struct DistrictInfoContentView: View {
    let district: District
    let performances: [Performance]
    @Binding var region: MKCoordinateRegion?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Color.clear
                    .frame(height: 220)

                if let description = district.description {
                    InfoMaterialContainer {
                        ExpandableTextView(text: description)
                    }
                }

                if !performances.isEmpty {
                    InfoMaterialContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("余興")
                                .font(.headline)

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)
                                ],
                                spacing: 8
                            ) {
                                ForEach(performances) { item in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(item.name)
                                            .font(.headline)
                                            .lineLimit(2)
                                        Text(item.performer)
                                            .font(.subheadline)
                                            .lineLimit(2)
                                        if let description = item.description {
                                            Text(description)
                                                .font(.footnote)
                                                .lineLimit(5)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
                                    .padding(12)
                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }
                        }
                    }
                }

                InfoMaterialContainer {
                    InfoMapView(
                        base: district.base,
                        area: district.area,
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
                lightPath: district.image.light,
                darkPath: district.image.dark,
                blurRadius: 8
            )
            .ignoresSafeArea()
        }
        .navigationTitle(district.name)
        .navigationBarTitleDisplayMode(.large)
    }
}
