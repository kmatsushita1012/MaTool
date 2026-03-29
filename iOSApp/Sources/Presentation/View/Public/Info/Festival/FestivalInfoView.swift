//
//  FestivalInfoView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/29.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

struct FestivalInfoView: View {
    @Perception.Bindable var store: StoreOf<FestivalInfoFeature>
    
    var body: some View {
        WithPerceptionTracking {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        TitleView(
                            text: store.festival.name,
                            image: "InfoBackground"
                        ) {
                            store.send(.dismissTapped)
                        }
                        
                        if let imagePath = store.festival.image.light {
                            VStack {
                                WebImageView(imagePath: imagePath, contentMode: .fit)
                            }
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                        
                        if !store.festival.prefecture.isEmpty || !store.festival.city.isEmpty {
                            HStack {
                                Text("\(store.festival.prefecture)\(store.festival.city)")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)
                                Spacer()
                            }
                        }
                        
                        if let description = store.festival.description {
                            VStack {
                                ScrollableTextView(description, maxHeight: 192)
                                    .padding()
                            }
                            .background(Color.info.opacity(0.3))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                        
                        VStack {
                            InfoMapView(
                                base: store.festival.base,
                                baseTitle: store.festival.subname,
                                area: [],
                                region: $store.region
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(UIColor.separator), lineWidth: 0.5)
                            )
                        }
                        .frame(height: 384)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 88)
                }
                
                VStack {
                    Spacer()
                    mapButton()
                        .padding(32)
                }
            }
            .ignoresSafeArea()
            .dismissible(backButton: false)
            .dismissOnChange(of: store.isDismissed)
            .loadingOverlay(store.isLoading)
        }
    }
    
    @ViewBuilder
    func mapButton() -> some View {
        Button(action: {
            store.send(.mapTapped)
        }) {
            HStack(spacing: 16) {
                Text("現在地一覧")
                    .font(.title3)
                Image(systemName: "location.fill")
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 8)
        }
        .clipShape(.capsule)
        .buttonStyle(.borderedProminent)
        .tint(Color.info)
    }
}
