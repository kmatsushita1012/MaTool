import ComposableArchitecture
import Dependencies
import MapKit
import SwiftUI
import Shared
import UIKit

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
        }
    }
}

private struct FestivalInfoContentView: View {
    @Dependency(\.values.isLiquidGlassEnabled) private var isLiquidGlassEnabled

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
            if #available(iOS 26.0, *), isLiquidGlassEnabled {
                displayContent
                    .safeAreaInset(edge: .top, spacing: 0) {
                        displayModePicker
                            .glassEffect(.regular)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                    }
            } else {
                VStack(spacing: 0) {
                    displayModePicker
                        .padding(.horizontal)
                    displayContent
                    Spacer(minLength: 0)
                }
            }
        }
        .background {
            InfoImageBlurredBackgroundView(
                lightPath: festival.image.light,
                darkPath: festival.image.dark
            )
            .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSheetRoot {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("閉じる")
                    .disabled(isLoading)
                }
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarLeading)
            }
            ToolbarItem(placement: .topBarLeading) {
                Text(festival.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .hideSharedBackgroundVisibility()
        }
    }

    private var displayModePicker: some View {
        Picker("紹介表示", selection: $displayMode) {
            ForEach(FestivalInfoFeature.DisplayMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .modifier(FestivalInfoSegmentPickerStyleModifier())
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var displayContent: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FestivalInfoSegmentPickerStyleModifier: ViewModifier {
    init() {
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: UIFont.preferredFont(forTextStyle: .body)],
            for: .normal
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: UIFont.preferredFont(forTextStyle: .headline)],
            for: .selected
        )
    }

    func body(content: Content) -> some View {
        content
            .pickerStyle(.segmented)
            .controlSize(.large)
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
        InfoScrollView {
            ForEach(districtGroups) { group in
                FestivalDistrictGroupContentView(
                    group: group,
                    isLoading: isLoading,
                    selectedDistrictID: selectedDistrictID,
                    onDistrictSelected: onDistrictSelected
                )
            }
        }
    }

    private var districtGroups: [FestivalDistrictGroup] {
        var groups: [FestivalDistrictGroup] = []

        for district in districts {
            let trimmedGroup = district.group?.trimmingCharacters(in: .whitespacesAndNewlines)
            let groupName = trimmedGroup?.isEmpty == false ? trimmedGroup : nil

            if !groups.isEmpty, groups[groups.count - 1].name == groupName {
                groups[groups.count - 1].districts.append(district)
            } else {
                groups.append(FestivalDistrictGroup(name: groupName, districts: [district]))
            }
        }

        return groups
    }
}

private struct FestivalDistrictGroup: Identifiable {
    let name: String?
    var districts: [District]

    var id: String { name ?? "" }
}

private struct FestivalDistrictGroupContentView: View {
    let group: FestivalDistrictGroup
    let isLoading: Bool
    let selectedDistrictID: District.ID?
    let onDistrictSelected: (District.ID) -> Void

    var body: some View {
        InfoMaterialContainer {
            VStack(alignment: .leading, spacing: 0) {
                if let name = group.name {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)
                }

                ForEach(group.districts) { district in
                    if district.id != group.districts.first?.id {
                        Divider()
                    }

                    Button {
                        onDistrictSelected(district.id)
                    } label: {
                        HStack {
                            Text(district.name)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(.rect)
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .background(
                        selectedDistrictID == district.id ? Color.info.opacity(0.15) : .clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
            }
        }
    }
}

typealias FestivalInfoScreen = FestivalInfoView
