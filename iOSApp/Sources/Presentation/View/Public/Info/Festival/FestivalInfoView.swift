import ComposableArchitecture
import MapKit
import SwiftUI
import Shared

struct FestivalInfoView: View {
    @SwiftUI.Bindable var store: StoreOf<FestivalInfoFeature>
    let isSheetRoot: Bool

    var body: some View {
        WithPerceptionTracking {
            FestivalInfoContentView(
                festival: store.festival,
                districts: store.districts,
                isSheetRoot: isSheetRoot,
                displayMode: $store.displayMode,
                region: $store.region,
                isLoading: store.isLoading,
                selectedDistrictID: store.selectedDistrictID,
                onDistrictSelected: { store.send(.districtSelected($0)) }
            )
            .navigationDestination(item: $store.scope(
                state: \.destination,
                action: \.destination
            )) { destinationStore in
                switch destinationStore.case {
                case .district(let districtStore):
                    DistrictInfoView(
                        store: districtStore,
                        festivalName: nil,
                        onFestivalTapped: {},
                        isSheetRoot: false
                    )
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .loadingOverlay(store.isLoading)
        }
    }
}

private struct FestivalInfoContentView: View {
    let festival: Festival
    let districts: [District]
    let isSheetRoot: Bool
    @Binding var displayMode: FestivalInfoFeature.DisplayMode
    @Binding var region: MKCoordinateRegion?
    let isLoading: Bool
    let selectedDistrictID: District.ID?
    let onDistrictSelected: (District.ID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch displayMode {
            case .festival:
                FestivalOverviewContentView(festival: festival, region: $region)
            case .districts:
                FestivalDistrictListContentView(
                    districts: districts,
                    isLoading: isLoading,
                    selectedDistrictID: selectedDistrictID,
                    onDistrictSelected: onDistrictSelected
                )
            }
        }
        .navigationTitle(festival.name)
        .background {
            InfoImageBlurredBackgroundView(
                lightPath: festival.image.light,
                darkPath: festival.image.dark
            )
            .ignoresSafeArea()
        }
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if isSheetRoot {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("閉じる")
                }
            }
            ToolbarItem(placement: .principal) {
                Picker("紹介表示", selection: $displayMode) {
                    ForEach(FestivalInfoFeature.DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

private struct FestivalOverviewContentView: View {
    let festival: Festival
    @Binding var region: MKCoordinateRegion?
    @State private var isMapMovementLocked = true

    var body: some View {
        InfoScrollView {
            InfoHeaderImageView(
                lightPath: festival.image.light,
                darkPath: festival.image.dark
            )

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
                VStack(alignment: .leading, spacing: 8) {
                    Text("本部")
                        .font(.headline)

                    ZStack(alignment: .bottomTrailing) {
                        InfoMapView(
                            base: festival.base,
                            baseTitle: festival.subname,
                            area: [],
                            isMapMovementEnabled: !isMapMovementLocked,
                            region: $region
                        )
                        .frame(height: 384)

                        InfoMapMovementButton(isMapMovementLocked: $isMapMovementLocked)
                            .padding(8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

private struct FestivalDistrictListContentView: View {
    let districts: [District]
    let isLoading: Bool
    let selectedDistrictID: District.ID?
    let onDistrictSelected: (District.ID) -> Void

    var body: some View {
        List(districts) { district in
            Button {
                onDistrictSelected(district.id)
            } label: {
                HStack {
                    Text(district.name)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .listRowBackground(selectedDistrictID == district.id ? Color.info.opacity(0.15) : .clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .modifier(HardTopScrollEdgeEffectModifier())
    }
}

typealias FestivalInfoScreen = FestivalInfoView
