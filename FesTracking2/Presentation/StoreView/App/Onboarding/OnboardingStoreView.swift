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
        ZStack{
            VStack {
                Spacer()
                MenuSelector(
                    title: "祭典",
                    items: store.regions,
                    selection: $store.selectedRegion,
                    label: { region in
                        region?.name ?? "未設定"
                    },
                    isNullable: false,
                    footer: "「テスト」アカウントは業務用です。選択しないでください。"
                )
                Spacer()
                Menu {
                    if let districts = store.districts{
                        ForEach(districts, id: \.self) { district in
                            Button(district.name) {
                                store.send(.districtSelected(district))
                            }
                        }
                    }
                } label: {
                    Text("参加町の方")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                
                Button(action: {
                    store.send(.externalGuestTapped)
                }) {
                    Text("参加町以外からお越しの方")
                    
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding()
                
                Button(action: {
                    store.send(.adminTapped)
                }) {
                    Text("参加町代表者、管理者の方")
                    
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding()
            }
            .padding()
            .onAppear(){
                store.send(.onAppear)
            }
            .loadingOverlay(store.isRegionsLoading)
        }
    }
}
