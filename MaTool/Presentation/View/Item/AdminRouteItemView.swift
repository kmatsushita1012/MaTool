//
//  RouteItem.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/08.
//

import SwiftUI

struct AdminRouteItem: View {
    let text: String
    let onEdit: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        HStack{
            Text(text)
            Spacer()
            Button {
                onEdit()
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .tint(.blue)
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal,4)
            Button {
                onExport()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .tint(.blue)
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal,4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}
