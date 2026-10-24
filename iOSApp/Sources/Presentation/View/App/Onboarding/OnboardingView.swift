//
//  OnboardingView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/24.
//

import SwiftUI
import ComposableArchitecture
import Shared

struct OnboardingScreen: View {
    @SwiftUI.Bindable var store: StoreOf<OnboardingFeature>

    var body: some View {
        WithPerceptionTracking {
            OnboardingContentView(
                festivals: store.festivals,
                districts: store.districts,
                selectedFestival: $store.selectedFestival,
                festivalErrorMessage: store.festivalErrorMessaage,
                onDistrictSelected: { store.send(.districtSelected($0)) },
                onExternalGuestTapped: { store.send(.externalGuestTapped) }
            )
            .loadingOverlay(store.isLoading)
        }
    }
}

typealias OnboardingView = OnboardingScreen

struct OnboardingContentView: View {
    let festivals: [Festival]
    let districts: [District]
    @Binding var selectedFestival: Festival?
    let festivalErrorMessage: String?
    let onDistrictSelected: (District) -> Void
    let onExternalGuestTapped: () -> Void

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
                Text("① どの祭に参加しますか？")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                MenuSelector(
                    items: festivals,
                    selection: $selectedFestival,
                    label: { festival in
                        festival?.name ?? "未設定"
                    },
                    isNullable: false,
                    errorMessage: festivalErrorMessage,
                    borderColor : .onboarding
                )
                .padding(.horizontal)
            }
            VStack(spacing: 8){
                Text("② どのように祭に参加しますか？")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                Menu {
                    ForEach(districts.reversed(), id: \.self) { district in
                        Button(district.name) {
                            onDistrictSelected(district)
                        }
                    }
                } label: {
                    Text("参加町")
                }
                .buttonStyle(PrimaryButtonStyle(.onboarding))
                .id(districts)
                .padding(.horizontal)

                Button(action: onExternalGuestTapped) {
                    Text("観光・見物（参加町以外）")
                }
                .buttonStyle(SecondaryButtonStyle(.onboarding))
                .padding(.horizontal)
            }
        }
        .padding()
        .background {
            GeometryReader { proxy in
                Image("OnboardingBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    OnboardingContentView(
        festivals: [],
        districts: [],
        selectedFestival: .constant(nil),
        festivalErrorMessage: nil,
        onDistrictSelected: { _ in },
        onExternalGuestTapped: {}
    )
}
