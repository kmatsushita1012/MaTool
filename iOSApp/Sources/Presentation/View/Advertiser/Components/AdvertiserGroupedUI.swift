import SwiftUI

struct AdvertiserSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .padding(.horizontal, 18)

            VStack(spacing: 0) {
                content
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.bottom, 24)
    }
}

struct AdvertiserNavigationRow: View {
    let title: String
    var subtitle: String?
    var value: String?
    var systemImage: String?
    var isDestructive = false
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(titleColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(titleColor)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                }

                Spacer(minLength: 8)

                if let value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(titleColor)
            }
            .frame(minHeight: 54)
            .padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var titleColor: Color {
        if isDestructive { return Color(uiColor: .systemRed) }
        return Color(uiColor: .label)
    }
}

struct AdvertiserRowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 0.5)
            .padding(.leading, 18)
    }
}

struct AdvertiserGroupedPage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
