import CoreGraphics

/// Previous / next item within the list an item detail was opened from.
/// Pure so the order, bounds and swipe rules are unit-testable.
/// Satisfies: REQ-INV-020 (Swipe Between Items in Item Detail)
/// Acceptance criteria: AC1, AC2, AC3, AC4, AC6
/// Spec version: 1.0
struct ItemPager: Equatable {
    enum Step: Int {
        case previous = -1
        case next = 1
    }

    static let minSwipeDistance: CGFloat = 60
    /// Swipes starting this close to the left edge belong to the system back gesture.
    static let backEdgeInset: CGFloat = 24

    let ids: [String]

    /// Paging only makes sense with a list of at least two items (AC6).
    var isActive: Bool { ids.count > 1 }

    func neighbor(of id: String, _ step: Step) -> String? {
        guard isActive, let index = ids.firstIndex(of: id) else { return nil }
        let target = index + step.rawValue
        return ids.indices.contains(target) ? ids[target] : nil
    }

    /// "3 of 24"; nil when paging is off or the item is not in the list.
    func positionLabel(for id: String) -> String? {
        guard isActive, let index = ids.firstIndex(of: id) else { return nil }
        return "\(index + 1) of \(ids.count)"
    }

    /// Drops items that no longer exist (removed while the detail is open, AC1).
    func keeping(_ existing: Set<String>) -> ItemPager {
        ItemPager(ids: ids.filter(existing.contains))
    }

    /// Left swipe → next, right swipe → previous; nil for short, diagonal or back-edge drags (AC2).
    static func step(translation: CGSize, startX: CGFloat) -> Step? {
        let dx = translation.width
        let dy = translation.height
        guard abs(dx) >= minSwipeDistance, abs(dx) > abs(dy) * 1.5 else { return nil }
        if dx > 0, startX < backEdgeInset { return nil }
        return dx < 0 ? .next : .previous
    }
}
