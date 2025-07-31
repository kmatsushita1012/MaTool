//
//  DistrictInfoStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/29.
//

import ComposableArchitecture
import SwiftUI
import NavigationSwipeControl

struct DistrictInfoStoreView: View {
    @Bindable var store: StoreOf<DistrictInfo>
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TitleView(
                    text: store.item.name,
                    image: "SettingsBackground"
                ) {
                    store.send(.dismissTapped)
                }

                if let imagePath = store.item.imagePath {
                    VStack{
                        WebImageView(imagePath: imagePath)
                    }
                    .frame(height: 384)
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                if let description = store.item.description {
                    VStack{
                        ScrollableTextView(description, maxHeight: 192)
                            .padding()
                    }
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                // 横スクロール（上で修正したもの）
                if !store.item.performances.isEmpty{
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(store.item.performances) { item in
                                performance(item)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                VStack{
                    PublicDistrictMapView(
                        base: store.item.base,
                        area: store.item.area,
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
            .padding(.bottom, 32)
        }
        .ignoresSafeArea()
        .dismissible(backButton: false)
    }
    
    @ViewBuilder
    func performance(_ item: Performance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                
            Text(item.performer)
                .font(.subheadline)
                .lineLimit(1)

            if let description = item.description {
                ScrollableTextView(description, maxHeight: 128)
            }
            Spacer()
        }
        .padding()
        .frame(width: 256, height: 192, alignment: .topLeading)
        .background(Color.orange.opacity(0.3))
        .cornerRadius(8)
    }

}
