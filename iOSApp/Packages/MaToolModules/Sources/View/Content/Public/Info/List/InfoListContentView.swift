import iOSShared
import SwiftUI
import Shared

public struct InfoListContentView: View {
    let festivals: [Festival]
    let isLinked: Bool
    let isFestivalListLoading: Bool
    let onFestivalSelected: (Festival) -> Void

    public init(
        festivals: [Festival],
        isLinked: Bool,
        isFestivalListLoading: Bool,
        onFestivalSelected: @escaping (Festival) -> Void
    ) {
        self.festivals = festivals
        self.isLinked = isLinked
        self.isFestivalListLoading = isFestivalListLoading
        self.onFestivalSelected = onFestivalSelected
    }

    public var body: some View {
        List {
            InfoFestivalSection(isLinked: isLinked) {
                if festivals.isEmpty && isFestivalListLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack {
                            Text("祭典名")
                            Spacer()
                        }
                        .redacted(reason: .placeholder)
                    }
                } else {
                    ForEach(festivals) { festival in
                        Button {
                            onFestivalSelected(festival)
                        } label: {
                            HStack {
                                Text(festival.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(.rect)
                        }
                        .disabled(isFestivalListLoading)
                        .buttonStyle(.plain)
                    }
                }

                if isFestivalListLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(isLinked ? "祭を選択" : "紹介")
    }
}

private struct InfoFestivalSection<Content: View>: View {
    let isLinked: Bool
    private let content: () -> Content

    init(isLinked: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.isLinked = isLinked
        self.content = content
    }

    var body: some View {
        if isLinked {
            content()
        } else {
            Section("祭を選択", content: content)
        }
    }
}
