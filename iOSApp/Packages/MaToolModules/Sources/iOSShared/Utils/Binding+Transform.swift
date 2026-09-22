//
//  Bindings.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/11.
//

import SwiftUI
import Shared

public extension Binding {
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

public extension Binding where Value == String? {
    /// nil を "" に変換し、"" を nil に変換する Binding<String> を作成
    var nonOptional: Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { self.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

public extension Binding where Value == SimpleTime {
    var fullDate: Binding<Date> {
        Binding<Date>(
            get: { self.wrappedValue.toDate },
            set: { self.wrappedValue = SimpleTime.from($0) }
        )
    }
}

public extension Binding where Value == SimpleTime? {
    var fullDate: Binding<Date> {
        Binding<Date>(
            get: { self.wrappedValue?.toDate ?? Date() },
            set: { self.wrappedValue = SimpleTime.from($0) }
        )
    }

    var unwrapped: Binding<SimpleTime> {
        Binding<SimpleTime>(
            get: { self.wrappedValue ?? .now },
            set: { self.wrappedValue = $0 }
        )
    }

    var toggle: Binding<Bool> {
        Binding<Bool>(
            get: { self.wrappedValue != nil },
            set: { hasTime in
                if hasTime {
                    if self.wrappedValue == nil {
                        self.wrappedValue = .now
                    }
                } else {
                    self.wrappedValue = nil
                }
            }
        )
    }
}

public extension Binding where Value == SimpleDate {
    var fullDate: Binding<Date> {
        Binding<Date>(
            get: { self.wrappedValue.toDate },
            set: { self.wrappedValue = SimpleDate.from($0) }
        )
    }
}

public extension Binding where Value == Bool {
    var inverted: Binding<Bool> {
        Binding<Bool>(
            get: { !self.wrappedValue },
            set: { self.wrappedValue = !$0 }
        )
    }
}
