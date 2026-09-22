import iOSShared
//
//  RouteHistoryView.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/18.
//

import SwiftUI
import Shared
import SQLiteData


@available(iOS 17.0, *)
@Observable
public final class RouteHistoryPresenter {
    let districtId: District.ID
    let excludingRouteId: Route.ID?
    
    @ObservationIgnored
    @FetchAll var entry: [RouteEntry]
    
    let selected: (RouteEntry) -> Void
    
    private var groupedByYear: [Int: [RouteEntry]]
    
    var years: [Int] { groupedByYear.keys.sorted(by: >) }
    
    public init(
        districtId: District.ID,
        excludingRouteId: Route.ID? = nil,
        selected: @escaping (RouteEntry) -> Void
    ) {
        self.districtId = districtId
        self.excludingRouteId = excludingRouteId
        self.selected = selected
        let entryQuery: FetchAll<RouteEntry> = .init(districtId: districtId, latest: false)
        self._entry = entryQuery
        let filteredEntry = entryQuery.wrappedValue.filter { entry in
            entry.id != excludingRouteId
        }
        self.groupedByYear =  Dictionary(grouping: filteredEntry.sorted()) {
            $0.period.date.year
        }
    }
    
    func group(year: Int) -> [RouteEntry]? {
        groupedByYear[year]
    }
}

@available(iOS 17.0, *)
public struct RouteHistoryView: View {
    var presenter: RouteHistoryPresenter
    
    public init(_ presenter: RouteHistoryPresenter) {
        self.presenter = presenter
    }
    
    @Environment(\.dismiss) var dismiss
    
    public var body: some View {
        Form {
            ForEach(presenter.years, id: \.self) { year in
                Section("\(String(year))年") {
                    ForEach(presenter.group(year: year) ?? []) { entry in
                        Button(entry.period.shortText){
                            presenter.selected(entry)
                        }
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .navigationTitle("コピー元のルートを選択")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarCancelButton {
                dismiss()
            }
        }
    }
    
}
