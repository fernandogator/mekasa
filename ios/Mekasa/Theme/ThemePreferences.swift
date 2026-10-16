import Foundation
import SwiftUI

/// Seasonal / brand palette choice. Light and dark still follow the system appearance.
/// Spec version: 1.0 — Superdesign Halloween seasonal theme (2026-10-15).
enum MekasaPaletteStyle: String, CaseIterable, Identifiable {
    case grounded
    case halloween

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grounded: return "Grounded"
        case .halloween: return "Halloween"
        }
    }

    var subtitle: String {
        switch self {
        case .grounded: return "Original rich & earthy home palette."
        case .halloween: return "Spooky candy corn and slime theme."
        }
    }
}

/// Persists the seasonal palette and the October “try Halloween” prompt.
@MainActor
final class ThemePreferences: ObservableObject {
    static let shared = ThemePreferences()

    static let styleKey = "mekasa.paletteStyle"
    static let promptDismissedKey = "mekasa.halloweenPromptDismissed"

    @Published var style: MekasaPaletteStyle = .grounded {
        didSet { defaults.set(style.rawValue, forKey: Self.styleKey) }
    }

    /// Brief undo toast after enabling Halloween from the promo card.
    @Published var halloweenUndoVisible = false
    private var undoTask: Task<Void, Never>?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.styleKey),
           let stored = MekasaPaletteStyle(rawValue: raw) {
            style = stored
        } else {
            style = .grounded
        }
    }

    var isHalloween: Bool { style == .halloween }

    /// Show the dashboard promo in October until dismissed or Halloween is on.
    var shouldShowHalloweenPrompt: Bool {
        guard !isHalloween else { return false }
        guard defaults.object(forKey: Self.promptDismissedKey) == nil else { return false }
        return Calendar.current.component(.month, from: Date()) == 10
    }

    func select(_ newStyle: MekasaPaletteStyle, showUndo: Bool = false) {
        let previous = style
        style = newStyle
        if showUndo, newStyle == .halloween, previous != .halloween {
            presentHalloweenUndo()
        }
        if newStyle == .halloween {
            defaults.set(true, forKey: Self.promptDismissedKey)
        }
    }

    func dismissHalloweenPrompt() {
        defaults.set(true, forKey: Self.promptDismissedKey)
        objectWillChange.send()
    }

    func undoHalloween() {
        style = .grounded
        halloweenUndoVisible = false
        undoTask?.cancel()
    }

    private func presentHalloweenUndo() {
        halloweenUndoVisible = true
        undoTask?.cancel()
        undoTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            halloweenUndoVisible = false
        }
    }
}
