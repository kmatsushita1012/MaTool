//
//  PublicMapContentView.swift
//  MaTool
//

import Shared
import SwiftUI

struct PublicMapContentView<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            content()
        }
    }
}

struct MapFestivalToolbarTitleContentView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title2)
            .bold()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct MapTopControlsContentView: View {
    let contents: [PublicMapFeature.Content]
    let selectedContent: PublicMapFeature.Content
    let isLoading: Bool
    let onContentSelected: (PublicMapFeature.Content) -> Void
    let routes: [RouteEntry]?
    let selectedPeriodTitle: String
    let isRouteLoading: Bool
    let isPeriodDisabled: Bool
    let onPeriodSelected: (RouteEntry) -> Void

    var body: some View {
        HStack(spacing: 16) {
            MapContentMenuContentView(
                contents: contents,
                selectedContent: selectedContent,
                isLoading: isLoading,
                onSelected: onContentSelected
            )
            if let routes {
                MapPeriodMenuContentView(
                    routes: routes,
                    selectedTitle: selectedPeriodTitle,
                    isLoading: isRouteLoading,
                    isDisabled: isPeriodDisabled,
                    onSelected: onPeriodSelected
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }
}

private struct MapContentMenuContentView: View {
    let contents: [PublicMapFeature.Content]
    let selectedContent: PublicMapFeature.Content
    let isLoading: Bool
    let onSelected: (PublicMapFeature.Content) -> Void
    @ScaledMetric(relativeTo: .body) private var districtIconSize = 20

    var body: some View {
        Menu {
            ForEach(contents, id: \.self) { item in
                Button {
                    guard item != selectedContent else { return }
                    onSelected(item)
                } label: {
                    if item == selectedContent {
                        Label(item.text, systemImage: "checkmark")
                    } else {
                        Text(item.text)
                    }
                }
            }
        } label: {
            Label {
                Text(selectedContent.text)
            } icon: {
                if case .route = selectedContent {
                    Image("DistrictMenuIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: districtIconSize, height: districtIconSize)
                } else {
                    Image(systemName: "mappin.and.ellipse")
                }
            }
        }
        .overlay(alignment: .trailing) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .disabled(isLoading)
        .modifier(MapTopMenuButtonStyleModifier())
    }
}

private struct MapPeriodMenuContentView: View {
    let routes: [RouteEntry]
    let selectedTitle: String
    let isLoading: Bool
    let isDisabled: Bool
    let onSelected: (RouteEntry) -> Void

    var body: some View {
        Menu {
            ForEach(routes) { entry in
                Button(entry.period.mapMenuText) {
                    onSelected(entry)
                }
            }
        } label: {
            Label(selectedTitle, systemImage: "calendar")
        }
        .overlay(alignment: .trailing) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .disabled(isDisabled || isLoading || routes.isEmpty)
        .modifier(MapTopMenuButtonStyleModifier())
    }
}

extension Period {
    var mapMenuText: String {
        "\(date.text(format: "m/d（w）"))\(title)"
    }
}

private struct MapTopMenuButtonStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .menuStyle(.button)
                .buttonStyle(.glass)
                .buttonSizing(.fitted)
                .controlSize(.large)
        } else {
            content
                .menuStyle(.button)
                .buttonStyle(.plain)
                .controlSize(.large)
        }
    }
}
