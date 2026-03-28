//
//  Bindings.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/11.
//

import SwiftUI
import Shared

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
            set: { self.wrappedValue = SimpleTime.from($0) }
        )
    }
}

extension Binding where Value == SimpleTime? {
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
}

extension Binding where Value == SimpleDate {
    var fullDate: Binding<Date> {
        Binding<Date>(
            get: { self.wrappedValue.toDate },
            set: { self.wrappedValue = SimpleDate.from($0) }
        )
    }
}

extension Binding where Value == SimpleTime? {
    var toggle: Binding<Bool> {
        Binding<Bool>(
            get: { self.wrappedValue != nil },
            set: { hasTime in
                if hasTime {
                    // nil から非 nil にする場合は、前回の値を復元
                    // それが無ければ現在時刻
                    if self.wrappedValue == nil {
                        self.wrappedValue = .now
                    }
                } else {
                    // 非 nil から nil にする前に cache を保持
                    self.wrappedValue = nil
                }
            }
        )
    }
}

extension Binding where Value == Bool {
    var inverted: Binding<Bool> {
        Binding<Bool>(
            get: { !self.wrappedValue },
            set: { self.wrappedValue = !$0 }
        )
    }
}
