public enum MenuPanelRenderMode: Equatable, Sendable {
    case inert
    case live
}

public struct MenuPanelVisibilityState: Equatable, Sendable {
    public private(set) var windowIsVisible: Bool

    public init(windowIsVisible: Bool = false) {
        self.windowIsVisible = windowIsVisible
    }

    public var renderMode: MenuPanelRenderMode {
        windowIsVisible ? .live : .inert
    }

    public mutating func update(windowIsVisible: Bool) {
        self.windowIsVisible = windowIsVisible
    }
}
