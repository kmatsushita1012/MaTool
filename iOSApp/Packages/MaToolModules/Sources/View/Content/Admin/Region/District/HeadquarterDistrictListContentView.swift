import iOSShared
//
//  HeadquarterDistrictListContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
public struct HeadquarterDistrictListContentView: View {
    let isReordering: Bool
    @Binding var searchText: String
    let draftDistricts: [District]?
    let districts: [District]
    let filteredDistricts: [District]
    let isLoading: Bool
    let isReorderDisabled: Bool
    let isExportLoading: Bool
    let onDistrictSelected: (District) -> Void
    let onDistrictMoved: (IndexSet, Int) -> Void
    let onBatchExport: () -> Void
    let onReorder: () -> Void
    let onCreate: () -> Void

    public init(
        isReordering: Bool,
        searchText: Binding<String>,
        draftDistricts: [District]?,
        districts: [District],
        filteredDistricts: [District],
        isLoading: Bool,
        isReorderDisabled: Bool,
        isExportLoading: Bool,
        onDistrictSelected: @escaping (District) -> Void,
        onDistrictMoved: @escaping (IndexSet, Int) -> Void,
        onBatchExport: @escaping () -> Void,
        onReorder: @escaping () -> Void,
        onCreate: @escaping () -> Void
    ) {
        self.isReordering = isReordering
        self._searchText = searchText
        self.draftDistricts = draftDistricts
        self.districts = districts
        self.filteredDistricts = filteredDistricts
        self.isLoading = isLoading
        self.isReorderDisabled = isReorderDisabled
        self.isExportLoading = isExportLoading
        self.onDistrictSelected = onDistrictSelected
        self.onDistrictMoved = onDistrictMoved
        self.onBatchExport = onBatchExport
        self.onReorder = onReorder
        self.onCreate = onCreate
    }

    public var body: some View {
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    if isReordering {
                        Button("完了", action: onReorder)
                            .buttonStyle(.borderedProminent)
                            .overlay {
                                if isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                            .disabled(isLoading)
                    } else {
                        Button("並替", action: onReorder)
                            .disabled(isReorderDisabled || isLoading)
                        Button("追加", action: onCreate)
                    }
                }
            }
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
