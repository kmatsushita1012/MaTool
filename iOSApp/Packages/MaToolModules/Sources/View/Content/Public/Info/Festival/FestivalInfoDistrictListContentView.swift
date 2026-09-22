import iOSShared
import SwiftUI
import Shared

public struct FestivalInfoDistrictListContentView: View {
    let districts: [District]
    let isLoading: Bool
    let onDistrictSelected: (District) -> Void

    public init(
        districts: [District],
        isLoading: Bool,
        onDistrictSelected: @escaping (District) -> Void
    ) {
        self.districts = districts
        self.isLoading = isLoading
        self.onDistrictSelected = onDistrictSelected
    }

    public var body: some View {
        List(districts) { district in
            Button {
                onDistrictSelected(district)
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .modifier(SoftTopScrollEdgeEffectModifier())
    }
}
