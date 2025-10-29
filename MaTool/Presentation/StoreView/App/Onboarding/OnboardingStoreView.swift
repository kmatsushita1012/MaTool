//
//  OnBoardingView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/24.
//

import SwiftUI
import ComposableArchitecture

struct OnboardingStoreView: View {
    
    @Perception.Bindable var store: StoreOf<OnboardingFeature>
    
    var body: some View {
        WithPerceptionTracking {
            ZStack {
                GeometryReader { proxy in
                    Image("OnboardingBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width,
                               height: proxy.size.height)
                        .clipped()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                VStack(spacing: 16) {
                    Text("MaToolへ\nようこそ")
                        .font(.custom("Kanit", size: 34))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    GeometryReader { proxy in
                        Image("LaunchImage")
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    }
                    VStack(spacing: 8){
                        Text("① どの祭に参加しますか？")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        MenuSelector(
                            items: store.regions,
                            selection: $store.selectedRegion,
                            label: { region in
                                region?.name ?? "未設定"
                            },
                            isNullable: false,
                            errorMessage: store.regionErrorMessaage,
                            footer: "「テスト」は業務用です。選択しないでください。\n設定画面から変更が可能です。",
                            borderColor : .onboarding
                        )
                        .padding(.horizontal)
                    }
                    VStack(spacing: 8){
                        Text("② どのように祭に参加しますか？")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        Menu {
                            if let districts = store.districts {
                                ForEach(districts, id: \.self) { district in
                                    Button(district.name) {
                                        store.send(.districtSelected(district))
                                    }
                                }
                            }
                        } label: {
                            Text("参加町")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundColor(.white)
                                .background(Color.onboarding)
                                .cornerRadius(8)
                        }
                        .id(store.districts)
                        .padding(.horizontal)
                        
                        Button(action: {
                            store.send(.externalGuestTapped)
                        }) {
                            Text("観光・見物（参加町以外）")
                            
                        }
                        .buttonStyle(SecondaryButtonStyle(.onboarding))
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .onAppear(){
                store.send(.onAppear)
            }
            
            .loadingOverlay(store.isLoading)
        }
    }
}
