import ComposableArchitecture
import MapKit
import SwiftUI
import Shared

struct DistrictInfoView: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictInfoFeature>
    let festivalName: String?
    var locationTimestamp: Date? = nil
    var isNavigationLoading = false
    let onFestivalTapped: () -> Void
    let isSheetRoot: Bool

    var body: some View {
        WithPerceptionTracking {
            DistrictInfoContentView(
                district: store.district,
                performances: store.performances,
                region: $store.region,
                isSheetRoot: isSheetRoot,
                festivalName: festivalName,
                locationTimestamp: locationTimestamp,
                isNavigationLoading: isNavigationLoading,
                onFestivalTapped: onFestivalTapped
            )
        }
    }
}

private struct DistrictInfoContentView: View {
    let district: District
    let performances: [Performance]
    @Binding var region: MKCoordinateRegion?
    let isSheetRoot: Bool
    let festivalName: String?
    let locationTimestamp: Date?
    let isNavigationLoading: Bool
    let onFestivalTapped: () -> Void
    @State private var isMapMovementLocked = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        InfoScrollView {
            InfoHeaderImageView(
                lightPath: district.image.light,
                darkPath: district.image.dark
            )

            if let description = district.description {
                InfoMaterialContainer {
                    ExpandableTextView(text: description)
                }
            }

            if !performances.isEmpty {
                InfoMaterialContainer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("余興")
                            .font(.headline)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ],
                            spacing: 8
                        ) {
                            ForEach(performances) { performance in
                                PerformanceInfoCardView(performance: performance)
                            }
                        }
                    }
                }
            }

            InfoMaterialContainer {
                VStack(alignment: .leading, spacing: 8) {
                    Text("会所と町域")
                        .font(.headline)

                    ZStack(alignment: .bottomTrailing) {
                        InfoMapView(
                            base: district.base,
                            area: district.area,
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
        .background {
            InfoImageBlurredBackgroundView(
                lightPath: district.image.light,
                darkPath: district.image.dark
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
                    .disabled(isNavigationLoading)
                }
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarLeading)
            }
            ToolbarItem(placement: .topBarLeading) {
                Group {
                    if let locationTimestamp {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(district.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(locationTimestamp, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text(district.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .hideSharedBackgroundVisibility()
            if isSheetRoot {
                if let festivalName {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(festivalName, action: onFestivalTapped)
                        .disabled(isNavigationLoading)
                    }
                }
            }
        }
    }
}

private struct PerformanceInfoCardView: View {
    let performance: Performance

    @State private var isExpanded = false
    @State private var naturalContentHeight: CGFloat?

    private let collapsedContentHeight: CGFloat = 160

    var body: some View {
        Group {
            if let description = performance.description {
                if isExpanded || !shouldShowMoreButton {
                    cardContent(description: description, descriptionLineLimit: nil, showsMoreButton: false)
                } else {
                    ViewThatFits(in: .vertical) {
                        cardContent(description: description, descriptionLineLimit: 5, showsMoreButton: true)
                        cardContent(description: description, descriptionLineLimit: 4, showsMoreButton: true)
                        cardContent(description: description, descriptionLineLimit: 3, showsMoreButton: true)
                        cardContent(description: description, descriptionLineLimit: 2, showsMoreButton: true)
                        cardContent(description: description, descriptionLineLimit: 1, showsMoreButton: true)
                    }
                    .frame(height: collapsedContentHeight, alignment: .topLeading)
                }
            } else {
                cardContent(
                    description: nil,
                    descriptionLineLimit: nil,
                    showsMoreButton: false
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background {
            if performance.description != nil {
                cardContent(
                    description: performance.description,
                    descriptionLineLimit: nil,
                    showsMoreButton: false
                )
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .hidden()
                .overlay {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: PerformanceCardContentHeightKey.self,
                            value: max(0, proxy.size.height - 24)
                        )
                    }
                }
            }
        }
        .onPreferenceChange(PerformanceCardContentHeightKey.self) { height in
            guard abs((naturalContentHeight ?? 0) - height) > 0.5 else { return }
            naturalContentHeight = height
        }
    }

    private var shouldShowMoreButton: Bool {
        naturalContentHeight.map { $0 > collapsedContentHeight } ?? false
    }

    private func cardContent(
        description: String?,
        descriptionLineLimit: Int?,
        showsMoreButton: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(performance.name)
                .font(.headline)
                .lineLimit(2)
            Text(performance.performer)
                .font(.subheadline)
                .lineLimit(2)

            if let description {
                Text(description)
                    .font(.footnote)
                    .lineLimit(descriptionLineLimit)
                    .fixedSize(horizontal: false, vertical: true)

                if showsMoreButton {
                    Button("もっと読む") {
                        isExpanded = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                }
            }
        }
    }
}

private struct PerformanceCardContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

typealias DistrictInfoScreen = DistrictInfoView

struct DistrictIntroductionRootView: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictIntroductionRootFeature>

    var body: some View {
        WithPerceptionTracking {
            DistrictInfoView(
                store: store.scope(state: \.district, action: \.district),
                festivalName: store.festival.name,
                locationTimestamp: store.locationTimestamp,
                isNavigationLoading: store.isLoading,
                onFestivalTapped: { store.send(.festivalTapped) },
                isSheetRoot: true
            )
            .navigationDestination(item: $store.scope(
                state: \.destination,
                action: \.destination
            )) { destinationStore in
                switch destinationStore.case {
                case .festival(let festivalStore):
                    FestivalInfoView(store: festivalStore, isSheetRoot: false)
                }
            }
        }
    }
}
