import iOSShared
import SwiftUI

struct MapGlassControlsContainer<Content: View>: View {
    let content: (Namespace.ID) -> Content
    let variant: MapGlassControlVariant
    @Namespace private var glassNamespace

    init(
        variant: MapGlassControlVariant,
        @ViewBuilder content: @escaping (Namespace.ID) -> Content
    ) {
        self.variant = variant
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: variant.spacing) {
                HStack(spacing: variant.spacing) {
                    content(glassNamespace)
                }
            }
        } else {
            HStack(spacing: 0) {
                content(glassNamespace)
            }
            .buttonStyle(.plain)
            .padding(variant.contentPadding)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

struct MapGlassControlRow<SliderContent: View, ControlsContent: View>: View {
    let isReplaying: Bool
    let spacing: CGFloat
    private let sliderContent: () -> SliderContent
    private let controlsContent: () -> ControlsContent

    init(
        isReplaying: Bool,
        spacing: CGFloat,
        @ViewBuilder slider: @escaping () -> SliderContent,
        @ViewBuilder controls: @escaping () -> ControlsContent
    ) {
        self.isReplaying = isReplaying
        self.spacing = spacing
        self.sliderContent = slider
        self.controlsContent = controls
    }

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            if isReplaying {
                sliderContent()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
            }
            controlsContent()
        }
        .frame(maxWidth: .infinity)
    }
}

enum MapGlassControlVariant {
    case toolbar

    var spacing: CGFloat { 0 }
    var sliderSpacing: CGFloat { 16 }
    var edgeSpacing: CGFloat { 16 }
    var contentPadding: CGFloat { 8 }
    var controlSize: ControlSize { .mini }

    @available(iOS 26.0, *)
    var glass: Glass { .regular.interactive() }
}

struct MapGlassButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void
    let namespace: Namespace.ID

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Label("", systemImage: systemImage)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(accessibilityLabel)
            .glassEffectUnion(id: "toolbar", namespace: namespace)
        } else {
            Button(action: action) {
                Label("", systemImage: systemImage)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        }
    }
}

struct MapGlassMenu: View {
    let floats: [FloatEntry]
    let onSelected: (FloatEntry) -> Void
    let namespace: Namespace.ID

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            menu
                .buttonStyle(.glass)
                .glassEffectUnion(id: "toolbar", namespace: namespace)
        } else {
            menu.buttonStyle(.plain)
        }
    }

    private var menu: some View {
        Menu {
            ForEach(floats, id: \.self) { entry in
                Button(entry.district.name) {
                    onSelected(entry)
                }
            }
        } label: {
            Label("", systemImage: "mappin.and.ellipse")
                .labelStyle(.iconOnly)
                .font(.title2)
                .padding(8)
        }
        .accessibilityLabel("現在地を選択")
    }
}

extension View {
    @ViewBuilder
    func mapSliderGlass(variant: MapGlassControlVariant) -> some View {
        let slider = controlSize(variant.controlSize)
            .frame(maxWidth: .infinity)
            .padding(variant.contentPadding)

        if #available(iOS 26.0, *) {
            slider.glassEffect(variant.glass, in: .capsule)
        } else {
            slider.background(.ultraThinMaterial, in: Capsule())
        }
    }
}
