import iOSShared
//
//  OnboardingContentView.swift
//  MaTool
//

import SwiftUI
import Shared

public struct OnboardingContentView: View {
    let festivals: [Festival]
    @Binding var selectedFestival: Festival?
    let festivalErrorMessage: String?
    let districts: [District]
    let isLoading: Bool
    let onDistrictSelected: (District) -> Void
    let onExternalGuestTapped: () -> Void

    public init(
        festivals: [Festival],
        selectedFestival: Binding<Festival?>,
        festivalErrorMessage: String?,
        districts: [District],
        isLoading: Bool,
        onDistrictSelected: @escaping (District) -> Void,
        onExternalGuestTapped: @escaping () -> Void
    ) {
        self.festivals = festivals
        self._selectedFestival = selectedFestival
        self.festivalErrorMessage = festivalErrorMessage
        self.districts = districts
        self.isLoading = isLoading
        self.onDistrictSelected = onDistrictSelected
        self.onExternalGuestTapped = onExternalGuestTapped
    }

    public var body: some View {
        ZStack {
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
                VStack(spacing: 8) {
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
                        borderColor: .onboarding
                    )
                    .padding(.horizontal)
                }
                VStack(spacing: 8) {
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
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .background(Color.onboarding)
                            .cornerRadius(8)
                    }
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
        }
        .loadingOverlay(isLoading)
    }
}
