import ComposableArchitecture
import MapKit
import SwiftUI
import Shared

struct DistrictInfoView: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictInfoFeature>
    let festivalName: String?
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
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(performance.name)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Text(performance.performer)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                    if let description = performance.description {
                                        Text(description)
                                            .font(.footnote)
                                            .lineLimit(5)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
                                .padding(12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        .navigationTitle(district.name)
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
                if let festivalName {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(festivalName, action: onFestivalTapped)
                    }
                }
            }
        }
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
            .loadingOverlay(store.isLoading)
        }
    }
}
