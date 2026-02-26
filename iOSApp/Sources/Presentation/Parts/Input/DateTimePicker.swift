//
//  DateTimePicker.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import SwiftUI
import Shared

typealias DateTimePicker = SwiftUI.DatePicker

struct DatePicker: View {
    private let title: String
    @Binding private var date: SimpleDate
    
    init(_ title: String = "日付を選択", selection date: Binding<SimpleDate>) {
        self.title = title
        self._date = date
    }
    
    var body: some View {
        DateTimePicker(
            title,
            selection: $date.fullDate,
            displayedComponents: [.date]
        )
        .environment(\.locale, Locale(identifier: "ja_JP"))
    }
}

struct TimePicker: View {
    private let title: String
    @Binding private var time: SimpleTime
    
    init(_ title: String = "時刻を選択", selection time: Binding<SimpleTime>) {
        self.title = title
        self._time = time
    }
    
    var body: some View {
        DateTimePicker(
            title,
            selection: $time.fullDate,
            displayedComponents: [.hourAndMinute]
        )
        .onAppear {
            UIDatePicker.appearance().minuteInterval = 5
        }
    }
}

struct YearPicker: View {
    private let title: String
    @Binding private var year: Int
    private var years: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(currentYear...(currentYear + 5))
    }
    
    init(_ title: String = "年を選択", selection: Binding<Int>) {
        self.title = title
        self._year = selection
    }
    
    
    var body: some View {
        Picker(title, selection: $year) {
            ForEach(years, id: \.self) { year in
                Text("\(String(year))年").tag(year)
            }
        }
    }
}
