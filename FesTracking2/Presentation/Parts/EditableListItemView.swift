//
//  PerformanceItemAdminView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//
import SwiftUI

struct EditableListItemView<T: Identifiable>: View {
    let text: String
    let onEdit: ()->Void
    let onDelete: ()->Void
    
    var body: some View {
        HStack{
            Text(text)
            Spacer()
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(BorderlessButtonStyle())
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
}
