//
//  ToggleItem.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/03.
//

import SwiftUI

struct ToggleSelectedItem: View {
    let title: String
    @Binding var isExpanded: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
            Spacer()
            Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                .foregroundColor(.gray)
                .padding(.leading, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                self.isExpanded.toggle()
            }
        }
    }
}

struct ToggleOptionItem: View {
    let title: String
    let onTap: ()->Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .padding(.leading, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                onTap()
            }
        }
    }
}
