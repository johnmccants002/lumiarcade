import SwiftUI

/// The single mapping from a canonical game identifier to its existing game root.
/// Neither game needs to know whether it came from the full app, App Clip, or NFC.
struct ArcadeGameView: View {
    let invocation: GameInvocation

    @ViewBuilder
    var body: some View {
        switch invocation.game {
        case .skyStack:
            SkyStackView(arcadot: invocation.arcadot)
        case .pulse:
            PulseView(arcadot: invocation.arcadot)
        }
    }
}
