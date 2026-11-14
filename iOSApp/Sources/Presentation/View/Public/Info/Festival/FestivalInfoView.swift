import ComposableArchitecture
import Dependencies
import MapKit
import SwiftUI
import Shared
import UIKit

struct FestivalInfoView: View {
    @SwiftUI.Bindable var store: StoreOf<FestivalInfoFeature>
    @Environment(\.colorScheme) private var systemColorScheme
    let isSheetRoot: Bool
    let showsCurrentLocationButton: Bool
    var onCurrentLocationTapped: () -> Void = {}
    var onRouteTapped: (District.ID) -> Void = { _ in }

    var body: some View {
        WithPerceptionTracking {
            FestivalInfoContentView(
                festival: store.festival,
                districts: store.districts,
                colorTheme: store.colorTheme,
                isSheetRoot: isSheetRoot,
                showsCurrentLocationButton: showsCurrentLocationButton,
                displayMode: $store.displayMode,
                region: $store.region,
                isLoading: store.isLoading,
                onDistrictSelected: { store.send(.districtSelected($0)) },
                onColorThemeSelected: { store.send(.colorThemeSelected($0)) },
                onCurrentLocationTapped: onCurrentLocationTapped
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
                        onRouteTapped: onRouteTapped,
                        isSheetRoot: false
                    )
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
        .onAppear {
            store.send(.colorThemeResolved(InfoImageColorScheme.resolve(
                lightPath: store.festival.image.light,
                darkPath: store.festival.image.dark,
                systemColorScheme: systemColorScheme
            )))
        }
        .preferredColorScheme(
            InfoImageColorScheme.preferredColorScheme(
                lightPath: store.festival.image.light,
                darkPath: store.festival.image.dark,
                systemColorScheme: systemColorScheme,
                selectedColorScheme: store.colorTheme
            )
        )
    }
}

private struct FestivalInfoContentView: View {
    @Dependency(\.values.isLiquidGlassEnabled) private var isLiquidGlassEnabled

    let festival: Festival
    let districts: [District]
    let colorTheme: ColorScheme?
    let isSheetRoot: Bool
    let showsCurrentLocationButton: Bool
    @Binding var displayMode: FestivalInfoFeature.DisplayMode
    @Binding var region: MKCoordinateRegion?
    let isLoading: Bool
    let onDistrictSelected: (District.ID) -> Void
    let onColorThemeSelected: (ColorScheme) -> Void
    let onCurrentLocationTapped: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var supportsThemeSwitch: Bool {
        InfoImageColorScheme.supportsThemeSwitch(
            lightPath: festival.image.light,
            darkPath: festival.image.dark
        )
    }

    private var themeToggleButton: some View {
        let effectiveColorScheme = InfoImageColorScheme.effective(
            systemColorScheme: colorScheme,
            selectedColorScheme: colorTheme
        )
        return InfoImageThemeToggleButton(colorScheme: effectiveColorScheme) {
            onColorThemeSelected(effectiveColorScheme == .dark ? .light : .dark)
        }
    }

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
            if showsCurrentLocationButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("現在地", action: onCurrentLocationTapped)
                }
            }
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
            if supportsThemeSwitch {
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.flexible, placement: .bottomBar)
                    ToolbarItem(placement: .bottomBar) {
                        themeToggleButton
                    }
                } else {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Spacer()
                        themeToggleButton
                    }
                }
            }
        }
        .environment(
            \.colorScheme,
            InfoImageColorScheme.effective(
                systemColorScheme: colorScheme,
            selectedColorScheme: colorTheme
            )
        )
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
                darkPath: festival.image.dark,
                title: festival.name
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
    let onDistrictSelected: (District.ID) -> Void

    var body: some View {
        InfoScrollView {
            ForEach(districtGroups) { group in
                FestivalDistrictGroupContentView(
                    group: group,
                    isLoading: isLoading,
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
    let onDistrictSelected: (District.ID) -> Void

    var body: some View {
        InfoMaterialContainer(verticalSpacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                if let name = group.name {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }

                VStack(spacing: 0) {
                    ForEach(group.districts) { district in
                        Button {
                            onDistrictSelected(district.id)
                        } label: {
                            HStack {
                                Text(district.name)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(.rect)
                            .padding(.horizontal, 8)
                        }
                        .tint(.primary)
                        .disabled(isLoading)

                        if district.id != group.districts.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

typealias FestivalInfoScreen = FestivalInfoView
