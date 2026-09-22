import iOSShared
//
//  RouteEditContentView.swift
//  MaTool
//

import SwiftUI

@available(iOS 17.0, *)
public struct RouteEditContentView<InfoContent: View, MapContent: View>: View {
    @Binding var tab: RouteEditTab
    let title: String
    let isLiquidGlassEnabled: Bool
    private let info: () -> InfoContent
    private let map: () -> MapContent

    public init(
        tab: Binding<RouteEditTab>,
        title: String,
        isLiquidGlassEnabled: Bool,
        @ViewBuilder info: @escaping () -> InfoContent,
        @ViewBuilder map: @escaping () -> MapContent
    ) {
        self._tab = tab
        self.title = title
        self.isLiquidGlassEnabled = isLiquidGlassEnabled
        self.info = info
        self.map = map
    }

    public var body: some View {
        Group {
            if #available(iOS 26.0, *), isLiquidGlassEnabled {
                Group {
                    if tab == .info {
                        info()
                    } else {
                        map()
                            .ignoresSafeArea(.container, edges: [.bottom, .top])
                    }
                }
                .safeAreaInset(edge: .top) {
                    RouteEditTabPicker(selection: $tab)
                        .glassEffect(.regular)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
            } else {
                VStack {
                    RouteEditTabPicker(selection: $tab)
                        .padding(.horizontal)
                    if tab == .info {
                        info()
                    } else {
                        map()
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 17.0, *)
private struct RouteEditTabPicker: View {
    @Binding var selection: RouteEditTab

    var body: some View {
        Picker("モード", selection: $selection) {
            Text("基本情報").tag(RouteEditTab.info)
            Text("地図編集").tag(RouteEditTab.edit)
            Text("一般公開").tag(RouteEditTab.`public`)
        }
        .routeSegmentPickerStyle()
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 17.0, *)
public struct RouteLongPressModeContentView: View {
    let operation: RouteEditOperation

    public init(operation: RouteEditOperation) {
        self.operation = operation
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("地図を長押しで")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("地点を\(operationLabel)")
                .foregroundStyle(.primary)
        }
        .frame(width: 100)
    }

    private var operationLabel: String {
        switch operation {
        case .add:
            return "追加"
        case .insert:
            return "挿入"
        case .move:
            return "移動"
        }
    }
}

@available(iOS 17.0, *)
public struct RouteEditSubmitButton: View {
    let isLoading: Bool
    let isPartialEnabled: Bool
    @Binding var isDialogPresented: Bool
    let onWhole: () -> Void
    let onPartial: () -> Void
    @State private var didTriggerLongPress = false

    public init(
        isLoading: Bool,
        isPartialEnabled: Bool,
        isDialogPresented: Binding<Bool>,
        onWhole: @escaping () -> Void,
        onPartial: @escaping () -> Void
    ) {
        self.isLoading = isLoading
        self.isPartialEnabled = isPartialEnabled
        self._isDialogPresented = isDialogPresented
        self.onWhole = onWhole
        self.onPartial = onPartial
    }

    public var body: some View {
        Button {
            if didTriggerLongPress {
                didTriggerLongPress = false
                return
            }
            onWhole()
        } label: {
            Text("提出用")
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .disabled(isLoading)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                if isPartialEnabled {
                    didTriggerLongPress = true
                    isDialogPresented = true
                }
            }
        )
        .confirmationDialog(
            "提出用PDFの出力方法を選択",
            isPresented: $isDialogPresented,
            titleVisibility: .visible
        ) {
            Button("全体を出力", action: onWhole)
            Button("表示範囲を出力", action: onPartial)
                .disabled(!isPartialEnabled)
        }
    }
}

private struct RouteSegmentPickerStyleModifier: ViewModifier {
    init() {
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: UIFont.preferredFont(forTextStyle: .body)],
            for: .normal
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: UIFont.preferredFont(forTextStyle: .headline)],
            for: .selected
        )
    }

    func body(content: Content) -> some View {
        content
            .pickerStyle(.segmented)
            .controlSize(.large)
    }
}

private extension View {
    func routeSegmentPickerStyle() -> some View {
        modifier(RouteSegmentPickerStyleModifier())
    }
}
