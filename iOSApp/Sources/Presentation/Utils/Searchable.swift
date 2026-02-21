//
//  Searchable.swift
//  MaTool
//
//  Created by Codex on 2026/02/21.
//

import SwiftUI

extension View {
    @ViewBuilder
    func searchable(text: Binding<String>, prompt: LocalizedStringKey, isEnabled: Bool) -> some View {
        if isEnabled {
            searchable(text: text, prompt: prompt)
        } else {
            self
        }
    }
}
