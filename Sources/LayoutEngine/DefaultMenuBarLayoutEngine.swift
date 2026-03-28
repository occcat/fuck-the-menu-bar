import Core
import Foundation

public struct DefaultMenuBarLayoutEngine: MenuBarLayoutEngineProtocol {
    public init() {}

    public func computeLayout(input: MenuBarLayoutInput) -> MenuBarLayoutResult {
        let sortedByPosition = input.items.sorted {
            if $0.descriptor.bounds.minX == $1.descriptor.bounds.minX {
                return $0.displayName.localizedCompare($1.displayName) == .orderedAscending
            }
            return $0.descriptor.bounds.minX < $1.descriptor.bounds.minX
        }

        let visible = sortedByPosition.filter { $0.rule.kind == .alwaysVisible }
        let masked = sortedByPosition.filter { $0.rule.kind != .alwaysVisible }
        let hiddenInShelf = sortedShelfItems(from: sortedByPosition, explicitOrder: input.hiddenOrder)

        return MenuBarLayoutResult(
            visibleItems: visible,
            maskedItems: masked,
            shelfItems: hiddenInShelf
        )
    }

    private func sortedShelfItems(from items: [ManagedMenuBarItem], explicitOrder: [String]) -> [ManagedMenuBarItem] {
        let orderMap = Dictionary(uniqueKeysWithValues: explicitOrder.enumerated().map { ($1, $0) })
        return items
            .filter { $0.rule.kind == .hiddenInBar }
            .sorted { lhs, rhs in
                let lhsIndex = orderMap[lhs.id] ?? Int.max
                let rhsIndex = orderMap[rhs.id] ?? Int.max
                if lhsIndex == rhsIndex {
                    return lhs.descriptor.bounds.minX < rhs.descriptor.bounds.minX
                }
                return lhsIndex < rhsIndex
            }
    }
}
