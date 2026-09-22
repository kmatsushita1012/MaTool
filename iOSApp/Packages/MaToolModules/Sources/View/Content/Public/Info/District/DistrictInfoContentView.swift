import iOSShared
import SwiftUI
import MapKit
import Shared

public struct DistrictInfoContentView: View {
    let district: District
    let performances: [Performance]
    @Binding var region: MKCoordinateRegion?
    @State private var imageBottomY: CGFloat?
    @State private var isMapMovementLocked = true

    public init(
        district: District,
        performances: [Performance],
        region: Binding<MKCoordinateRegion?>
    ) {
        self.district = district
        self.performances = performances
        self._region = region
    }

    public var body: some View {
        InfoScrollView(
            title: district.name,
            imageBottomY: imageBottomY
        ) {
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
                            ForEach(performances) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(item.name)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Text(item.performer)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                    if let description = item.description {
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

                        InfoMapMovementButton(
                            isMapMovementLocked: $isMapMovementLocked
                        )
                        .padding(8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .background {
            InfoImageBackgroundView(
                lightPath: district.image.light,
                darkPath: district.image.dark,
                blurRadius: 8
            )
            .ignoresSafeArea()
        }
        .onPreferenceChange(InfoBackgroundImageBottomPreferenceKey.self) {
            imageBottomY = $0
        }
    }
}
