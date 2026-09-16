import SwiftUI
import MapKit
import Shared

struct FestivalInfoOverviewContentView: View {
    let festival: Festival
    let imageBottomY: CGFloat?
    @Binding var region: MKCoordinateRegion?
    @State private var isMapMovementLocked = true

    var body: some View {
        InfoScrollView(
            title: festival.name,
            imageBottomY: imageBottomY
        ) {
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
