import Foundation

@MainActor
public protocol MenuBarDiscoveryServiceProtocol: AnyObject {
    var items: [MenuBarItemDescriptor] { get }
    var onItemsDidChange: (([MenuBarItemDescriptor]) -> Void)? { get set }
    func start()
    func stop()
    func rescan()
}

@MainActor
public protocol MenuBarInteractionRouterProtocol: AnyObject {
    func activate(item: MenuBarItemDescriptor, interactionMode: ProxyInteractionMode, button: MenuBarClickButton)
}

public protocol MenuBarLayoutEngineProtocol {
    func computeLayout(input: MenuBarLayoutInput) -> MenuBarLayoutResult
}

public protocol SettingsStoreProtocol: AnyObject {
    func load() throws -> AppSettings
    func save(_ settings: AppSettings) throws
}
