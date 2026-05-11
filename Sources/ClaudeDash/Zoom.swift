import SwiftUI

enum Zoom {
    static let key = "fontZoomIndex"
    static let defaultIndex = 3
    static let minIndex = 0
    static let maxIndex = 10

    static func factor(at index: Int) -> CGFloat {
        let clamped = min(max(index, minIndex), maxIndex)
        return 1.0 + 0.1 * CGFloat(clamped - defaultIndex)
    }
}

private struct ZoomFactorKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var zoomFactor: CGFloat {
        get { self[ZoomFactorKey.self] }
        set { self[ZoomFactorKey.self] = newValue }
    }
}

struct ZoomFont: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let monoDigit: Bool
    @Environment(\.zoomFactor) private var factor

    func body(content: Content) -> some View {
        let base = Font.system(size: size * factor, weight: weight, design: design)
        content.font(monoDigit ? base.monospacedDigit() : base)
    }
}

extension View {
    func zoomFont(_ size: CGFloat,
                  weight: Font.Weight = .regular,
                  design: Font.Design = .default,
                  monoDigit: Bool = false) -> some View {
        modifier(ZoomFont(size: size, weight: weight, design: design, monoDigit: monoDigit))
    }
}

struct ZoomCommands: Commands {
    @AppStorage(Zoom.key) private var index: Int = Zoom.defaultIndex

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()
            Button("Zoom In") {
                if index < Zoom.maxIndex { index += 1 }
            }
            .keyboardShortcut("=", modifiers: .command)
            Button("Zoom Out") {
                if index > Zoom.minIndex { index -= 1 }
            }
            .keyboardShortcut("-", modifiers: .command)
            Button("Actual Size") {
                index = Zoom.defaultIndex
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }
}
