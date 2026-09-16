//
//  PeriodArchivesContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
struct PeriodArchivesContentView: View {
    let year: Int
    let periods: [Period]
    let onPeriodTapped: (Period) -> Void

    var body: some View {
        Form {
            Section("\(String(year))年") {
                ForEach(periods) { period in
                    NavigationItemView(title: period.text) {
                        onPeriodTapped(period)
                    }
                }
            }
        }
    }
}
