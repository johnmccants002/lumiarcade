import SpriteKit
import SwiftUI

final class PulseGame: ObservableObject {
    let session: PulseSession
    let scene: PulseScene

    init(arcadot: Arcadot?) {
        let session = PulseSession(arcadot: arcadot)
        self.session = session
        scene = PulseScene(session: session)
    }
}

struct PulseView: View {
    @StateObject private var game: PulseGame
    private let switchConfirmationRequirementChanged: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(arcadot: Arcadot? = nil,
         switchConfirmationRequirementChanged: @escaping (Bool) -> Void = { _ in }) {
        _game = StateObject(wrappedValue: PulseGame(arcadot: arcadot))
        self.switchConfirmationRequirementChanged = switchConfirmationRequirementChanged
    }

    var body: some View {
        PulseContent(
            session: game.session,
            scene: game.scene,
            switchConfirmationRequirementChanged: switchConfirmationRequirementChanged
        )
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    game.scene.isPaused = false
                    game.scene.resumeClock()
                } else {
                    game.scene.suspend()
                }
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

private struct PulseContent: View {
    @ObservedObject var session: PulseSession
    let scene: PulseScene
    let switchConfirmationRequirementChanged: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.025, green: 0.055, blue: 0.12),
                                    Color(red: 0.035, green: 0.025, blue: 0.095),
                                    Color(red: 0.015, green: 0.025, blue: 0.055)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            RadialGradient(colors: [Color.cyan.opacity(0.08), .clear],
                           center: .leading, startRadius: 5, endRadius: 280)
                .ignoresSafeArea()
            SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.allowsTransparency])
                .ignoresSafeArea()
                .accessibilityLabel("Pulse game")
                .accessibilityHint("Double tap to pulse upward and travel through energy gates.")
                .accessibilityValue("Score \(session.score)")
                .accessibilityHidden(session.state == .gameOver)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { scene.pulse() }

            if session.state != .gameOver {
                VStack(spacing: 8) {
                    Text(GameType.pulse.displayName.uppercased())
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.52))
                    Text("\(session.score)")
                        .font(.system(size: 64, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.62),
                                   value: session.score)
                        .accessibilityIdentifier("liveScore")
                    if session.isNewBest || session.targetBest > 0 {
                        Text(session.isNewBest ? "NEW HIGH SCORE" : "HIGH  \(session.targetBest)")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(2)
                            .foregroundStyle(session.isNewBest
                                             ? Color(red: 0.52, green: 0.95, blue: 1)
                                             : .white.opacity(0.4))
                    }
                    Spacer()
                    if session.state == .ready {
                        Text("TAP TO PULSE")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(3)
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.bottom, 30)
                            .accessibilityIdentifier("pulseInstruction")
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
        .onAppear(perform: updateSwitchConfirmationRequirement)
        .onChange(of: session.state) { _, _ in updateSwitchConfirmationRequirement() }
        .onChange(of: session.resultStage) { _, _ in updateSwitchConfirmationRequirement() }
    }

    private func updateSwitchConfirmationRequirement() {
        let hasUnsavedRun = session.state != .gameOver || session.resultStage == .initials
        switchConfirmationRequirementChanged(hasUnsavedRun)
    }
}
