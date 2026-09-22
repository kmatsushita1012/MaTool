import iOSShared
//
//  PublicMapContentView.swift
//  MaTool
//

import Shared
import SwiftUI

public struct PublicMapContentView<Content: View>: View {
    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        ZStack {
            content()
        }
    }
}

public struct MapFestivalToolbarTitleContentView: View {
    let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.title2)
            .bold()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

public struct MapTopControlsContentView: View {
    let contents: [PublicMapContent]
    let selectedContent: PublicMapContent
    let isLoading: Bool
    let onContentSelected: (PublicMapContent) -> Void
    let routes: [RouteEntry]?
    let selectedPeriodTitle: String
    let isRouteLoading: Bool
    let isPeriodDisabled: Bool
    let onPeriodSelected: (RouteEntry) -> Void

    public init(
        contents: [PublicMapContent],
        selectedContent: PublicMapContent,
        isLoading: Bool,
        onContentSelected: @escaping (PublicMapContent) -> Void,
        routes: [RouteEntry]?,
        selectedPeriodTitle: String,
        isRouteLoading: Bool,
        isPeriodDisabled: Bool,
        onPeriodSelected: @escaping (RouteEntry) -> Void
    ) {
        self.contents = contents
        self.selectedContent = selectedContent
        self.isLoading = isLoading
        self.onContentSelected = onContentSelected
        self.routes = routes
        self.selectedPeriodTitle = selectedPeriodTitle
        self.isRouteLoading = isRouteLoading
        self.isPeriodDisabled = isPeriodDisabled
        self.onPeriodSelected = onPeriodSelected
    }

    public var body: some View {
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
    let contents: [PublicMapContent]
    let selectedContent: PublicMapContent
    let isLoading: Bool
    let onSelected: (PublicMapContent) -> Void
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
