import SwiftUI
import Shared

struct FestivalInfoDistrictListContentView: View {
    let districts: [District]
    let isLoading: Bool
    let onDistrictSelected: (District) -> Void

    var body: some View {
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
