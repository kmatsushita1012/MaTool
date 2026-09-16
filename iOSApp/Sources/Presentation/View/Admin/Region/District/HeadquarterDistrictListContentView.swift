//
//  HeadquarterDistrictListContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
struct HeadquarterDistrictListContentView: View {
    let isReordering: Bool
    @Binding var searchText: String
    let draftDistricts: [District]?
    let districts: [District]
    let filteredDistricts: [District]
    let isExportLoading: Bool
    let onDistrictSelected: (District) -> Void
    let onDistrictMoved: (IndexSet, Int) -> Void
    let onBatchExport: () -> Void

    var body: some View {
        Form {
            Section {
                if isReordering {
                    ForEach(draftDistricts ?? districts.sorted()) { district in
                        Text(district.name)
                    }
                    .onMove(perform: onDistrictMoved)
                } else {
                    ForEach(filteredDistricts) { district in
                        NavigationItemView(
                            title: district.name,
                            onTap: { onDistrictSelected(district) }
                        )
                    }
                }
            }
            #if DEBUG
            if !isReordering && searchText.isEmpty {
                Section {
                    HeadquarterListExportButton(
                        title: "提出資料出力",
                        showsProgress: isExportLoading,
                        isDisabled: isExportLoading,
                        action: onBatchExport
                    )
                }
            }
            #endif
        }
    }
}

@available(iOS 17.0, *)
private struct HeadquarterListExportButton: View {
    let title: String
    let showsProgress: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .trailing) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .disabled(isDisabled)
    }
}
