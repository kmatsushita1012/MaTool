import SwiftUI
import MapKit
import Shared

struct FestivalInfoContentView<FestivalContent: View, DistrictsContent: View>: View {
    let festival: Festival
    @Binding var displayMode: FestivalInfoFeature.DisplayMode
    private let festivalContent: (CGFloat?) -> FestivalContent
    private let districtsContent: () -> DistrictsContent
    @State private var imageBottomY: CGFloat?

    init(
        festival: Festival,
        displayMode: Binding<FestivalInfoFeature.DisplayMode>,
        @ViewBuilder festivalContent: @escaping (CGFloat?) -> FestivalContent,
        @ViewBuilder districtsContent: @escaping () -> DistrictsContent
    ) {
        self.festival = festival
        self._displayMode = displayMode
        self.festivalContent = festivalContent
        self.districtsContent = districtsContent
    }

    var body: some View {
        Group {
            switch displayMode {
            case .festival:
                festivalContent(imageBottomY)
            case .districts:
                districtsContent()
            }
        }
        .background {
            InfoImageBackgroundView(
                lightPath: festival.image.light,
                darkPath: festival.image.dark
            )
            .ignoresSafeArea()
        }
        .onPreferenceChange(InfoBackgroundImageBottomPreferenceKey.self) {
            imageBottomY = $0
        }
        .modifier(FestivalInfoNavigationTitleModifier(displayMode: displayMode))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("紹介表示", selection: $displayMode) {
                    ForEach(FestivalInfoFeature.DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

private struct FestivalInfoNavigationTitleModifier: ViewModifier {
    let displayMode: FestivalInfoFeature.DisplayMode

    @ViewBuilder
    func body(content: Content) -> some View {
        if case .districts = displayMode {
            content
                .navigationTitle("")
                .modifier(InfoInlineToolbarTitleModifier())
        } else {
            content
        }
    }
}
