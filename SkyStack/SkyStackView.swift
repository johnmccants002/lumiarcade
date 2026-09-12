import SwiftUI
import SpriteKit

final class SkyStackGame: ObservableObject {
    let session: SkyStackSession
    let scene: SkyStackScene

    init(arcadot: Arcadot?) {
        let session = SkyStackSession(arcadot: arcadot)
        self.session = session
        scene = SkyStackScene(session: session)
    }
}

struct SkyStackView: View {
    @StateObject private var game: SkyStackGame

    init(arcadot: Arcadot? = nil) {
        _game = StateObject(wrappedValue: SkyStackGame(arcadot: arcadot))
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        SkyStackContent(session: game.session, scene: game.scene)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { game.scene.isPaused = false; game.scene.resumeClock() }
                else { game.scene.suspend() }
            }
            .onAppear {
                game.scene.reduceMotion = reduceMotion
                game.scene.isPaused = scenePhase != .active
                game.scene.resumeClock()
            }
            .onChange(of: reduceMotion) { _, value in game.scene.reduceMotion = value }
            .onDisappear { game.scene.suspend() }
            .preferredColorScheme(.dark)
            .statusBarHidden()
    }
}

private struct SkyStackContent: View {
    @ObservedObject var session: SkyStackSession
    let scene: SkyStackScene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.15, blue: 0.22),
                                    Color(red: 0.035, green: 0.07, blue: 0.12),
                                    Color(red: 0.025, green: 0.045, blue: 0.075)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.allowsTransparency])
                .ignoresSafeArea()
                .accessibilityLabel("Stacking game")
                .accessibilityHint("Double tap to stack. With VoiceOver, the block slows and briefly holds when aligned. Listen for Aligned.")
                .accessibilityValue("Score \(session.score)")
                .accessibilityHidden(session.state == .gameOver)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { scene.placeMovingBlock() }
            if session.state != .gameOver {
                VStack(spacing: 10) {
                    Text(GameType.skyStack.displayName.uppercased())
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(session.score)")
                        .font(.system(size: 64, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: session.score)
                        .accessibilityIdentifier("liveScore")
                    if session.targetBest > 0 {
                        Text(session.isNewBest ? "NEW BEST" : "BEST  \(session.targetBest)")
                            .font(.system(size: 10, weight: .medium)).tracking(2)
                            .foregroundStyle(session.isNewBest ? Color(red: 0.98, green: 0.84, blue: 0.55) : .white.opacity(0.4))
                    }
                    Spacer()
                    if session.state == .ready {
                        Text("TAP TO STACK")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(3)
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.bottom, 30)
                    }
                }
                .padding(.top, 30)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
            if session.state == .gameOver {
                Color.black.opacity(0.82).ignoresSafeArea()
                ArcadeResultsView(session: session) { scene.restart() }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: session.state)

    }

}
