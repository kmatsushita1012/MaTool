import iOSShared
import SwiftUI

struct ExpandableTextView: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .lineLimit(isExpanded ? nil : 5)
                .multilineTextAlignment(.leading)

            if !isExpanded {
                Button("もっと読む") {
                    isExpanded = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            }
        }
    }
}
