//
//  RouteButton.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/08.
//
import SwiftUI

struct RouteButton: View{
    let systemImageName: String
    let action: ()->Void
    
    var body: some View{
        Button(action: action) {
            Image(systemName: systemImageName)
                .font(.title)
                .padding()
                .background(.regularMaterial)
                .clipShape(Circle())
        }
    }
}

#Preview {
    RouteButton(systemImageName: "checkmark", action: {()})
}
