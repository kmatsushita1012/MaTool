//
//  Bindings.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/11.
//

import SwiftUI
import ComposableArchitecture


extension Binding {
    /// 読み取り専用バインディング
    var readonly: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { _ in
                assertionFailure("Attempted to write to a read-only Binding.")
            }
        )
    }
}


extension Binding where Value == String? {
    /// nil を "" に変換し、"" を nil に変換する Binding<String> を作成
    var nonOptional: Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { self.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

extension Binding where Value == SimpleTime {
    var fullDate: Binding<Date> {
        Binding<Date>(
            get: { self.wrappedValue.toDate },
            set: { self.wrappedValue = SimpleTime.fromDate($0) }
        )
    }
}

extension Binding where Value == SimpleTime? {
    var fullDate: Binding<Date> {
        Binding<Date>(
            get: { self.wrappedValue?.toDate ?? Date() },
            set: { self.wrappedValue = SimpleTime.fromDate($0) }
        )
    }
}

extension Binding where Value == SimpleDate {
    var fullDate: Binding<Date> {
        Binding<Date>(
            get: { self.wrappedValue.toDate },
            set: { self.wrappedValue = SimpleDate.fromDate($0) }
        )
    }
}
