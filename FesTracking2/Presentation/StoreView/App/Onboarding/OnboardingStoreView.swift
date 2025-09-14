//
//  OnBoardingView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/24.
//

import SwiftUI
import ComposableArchitecture

struct OnboardingStoreView: View {
    
    @Bindable var store: StoreOf<OnboardingFeature>
    
    var body: some View {
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
                Text("① 祭典を選択してください")
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
                    footer: "「テスト」は業務用です。選択しないでください。",
                    borderColor : .onboarding
                )
                .padding(.horizontal)
            }
            VStack(spacing: 8){
                Text("② 祭典の参加方法を選択してください")
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
                    Text("参加町の方（地域住民の方）")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(.white)
                        .background(Color.onboarding)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Button(action: {
                    store.send(.externalGuestTapped)
                }) {
                    Text("参加町以外の方（観光等でお越しの方）")
                    
                }
                .buttonStyle(SecondaryButtonStyle(.onboarding))
                .padding(.horizontal)
            }
        }
        .padding()
        .onAppear(){
            store.send(.onAppear)
        }
        .background(
            Image("OnboardingBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        )
        .loadingOverlay(store.isLoading)
    }
}
