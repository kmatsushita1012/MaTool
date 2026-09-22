import iOSShared
//
//  PeriodArchivesContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
public struct PeriodArchivesContentView: View {
    let year: Int
    let periods: [Period]
    let onPeriodTapped: (Period) -> Void

    public init(year: Int, periods: [Period], onPeriodTapped: @escaping (Period) -> Void) {
        self.year = year
        self.periods = periods
        self.onPeriodTapped = onPeriodTapped
    }

    public var body: some View {
        Form {
            Section("\(String(year))年") {
                ForEach(periods) { period in
                    NavigationItemView(title: period.text) {
                        onPeriodTapped(period)
                    }
                }
            }
        }
        .navigationTitle("過去の日程")
        .navigationBarTitleDisplayMode(.inline)
    }
}
