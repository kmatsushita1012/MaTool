import iOSShared
import Shared
import SwiftUI

public struct MapTabContentView: View {
    let festivals: [Festival]
    let selectedFestivalID: Festival.ID?
    let isLinked: Bool
    let isLoading: Bool
    let isFestivalListLoading: Bool
    let onFestivalSelected: (Festival) -> Void

    public init(
        festivals: [Festival],
        selectedFestivalID: Festival.ID?,
        isLinked: Bool,
        isLoading: Bool,
        isFestivalListLoading: Bool,
        onFestivalSelected: @escaping (Festival) -> Void
    ) {
        self.festivals = festivals
        self.selectedFestivalID = selectedFestivalID
        self.isLinked = isLinked
        self.isLoading = isLoading
        self.isFestivalListLoading = isFestivalListLoading
        self.onFestivalSelected = onFestivalSelected
    }

    public var body: some View {
        List {
            MapFestivalSection(isLinked: isLinked) {
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
                            .overlay {
                                if isLoading && selectedFestivalID == festival.id {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                        }
                        .disabled(isLoading || isFestivalListLoading)
                        .buttonStyle(.plain)
                    }
                }

                if isFestivalListLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(isLinked ? "祭を選択" : "地図")
    }
}

private struct MapFestivalSection<Content: View>: View {
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
