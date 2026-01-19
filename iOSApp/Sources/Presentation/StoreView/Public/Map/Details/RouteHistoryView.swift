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
final class RouteHistoryPresenter {
    let districtId: District.ID
    
    @ObservationIgnored
    @FetchAll var entry: [RouteEntry]
    
    let selected: (RouteEntry) -> Void
    
    private var groupedByYear: [Int: [RouteEntry]]
    
    var years: [Int] { groupedByYear.keys.sorted(by: >) }
    
    init(districtId: District.ID, selected: @escaping (RouteEntry) -> Void) {
        self.districtId = districtId
        self.selected = selected
        let entryQuery: FetchAll<RouteEntry> = .init(districtId: districtId)
        self._entry = entryQuery
        self.groupedByYear =  Dictionary(grouping: entryQuery.wrappedValue.sorted()) {
            $0.period.date.year
        }
    }
    
    func group(year: Int) -> [RouteEntry]? {
        groupedByYear[year]
    }
}

@available(iOS 17.0, *)
struct RouteHistoryView: View {
    var presenter: RouteHistoryPresenter
    
    init(_ presenter: RouteHistoryPresenter) {
        self.presenter = presenter
    }
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
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
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(systemImage: "xmark") {
                    dismiss()
                }
            }
        }
    }
    
}
