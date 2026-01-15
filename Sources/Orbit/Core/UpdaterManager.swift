// UpdaterManager - Sparkle integration for automatic updates
// Provides SwiftUI-compatible updater controls

import Foundation
import Sparkle

/// ViewModel for observing Sparkle updater state
/// Used to enable/disable the "Check for Updates" button
@MainActor
public final class CheckForUpdatesViewModel: ObservableObject {
    @Published public var canCheckForUpdates = false

    public init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}
