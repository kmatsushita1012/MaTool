//
//  InfoStoreView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/08.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

struct InfoStoreView: View {
    @Perception.Bindable var store: StoreOf<InfoList>
    
    var body: some View {
        WithPerceptionTracking{
            VStack {
                // タイトル
                TitleView(
                    text: "町を見てみよう",
                    image: "InfoBackground"
                ) {
                    store.send(.homeTapped)
                }
                .ignoresSafeArea(edges: .top)
                VStack{
                    mainItem(store.region.name)
                        .onTapGesture{
                            #if DEBUG
                            store.send(.regionTapped)
                            #endif
                        }
                }
                .padding(.horizontal, 96)
                // スクロールする町名リスト
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.districts) { district in
                            listItem(district.name)
                                .onTapGesture{
                                    store.send(.districtTapped(district))
                                }
                        }
                    }
                    .padding(.horizontal, 64)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
                .mask(mask())
                VStack{
                    mainItem("　")
                }
                .padding(.horizontal, 96)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .dismissible(backButton: false)
            .navigationDestination(item: $store.scope(state: \.destination?.district, action: \.destination.district)) { store in
                WithPerceptionTracking{
                    DistrictInfoStoreView(store: store)
                }
            }
            .dismissOnChange(of: store.isDismissed)
        }
    }
    
    @ViewBuilder
    func mainItem(_ text: String) -> some View{
        Text(text)
            .font(.title)
            .foregroundColor(.black)
            .stroke(color: .white, width: 2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.info)
            .cornerRadius(8)
    }
    
    @ViewBuilder
    func listItem(_ text: String) -> some View {
        Text(text)
            .font(.title2)
            .foregroundColor(.black)
            .stroke(color: .white, width: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.info.opacity(0.6))
            .cornerRadius(8)
    }
        
    @ViewBuilder
    func mask() -> some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.05),
                .init(color: .black, location: 0.95),
                .init(color: .clear, location: 1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
