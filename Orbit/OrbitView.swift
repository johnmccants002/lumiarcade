import SpriteKit
import SwiftUI

final class OrbitGame: ObservableObject {
    let session: OrbitSession
    let scene: OrbitScene

    init(arcadot: Arcadot?) {
        let session = OrbitSession(arcadot: arcadot)
        self.session = session
        scene = OrbitScene(session: session)
    }
}

struct OrbitView: View {
    @StateObject private var game: OrbitGame
    private let switchConfirmationRequirementChanged: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(arcadot: Arcadot? = nil,
         switchConfirmationRequirementChanged: @escaping (Bool) -> Void = { _ in }) {
        _game = StateObject(wrappedValue: OrbitGame(arcadot: arcadot))
        self.switchConfirmationRequirementChanged = switchConfirmationRequirementChanged
    }

    var body: some View {
        OrbitContent(
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

private struct OrbitContent: View {
    @ObservedObject var session: OrbitSession
    let scene: OrbitScene
    let switchConfirmationRequirementChanged: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.045, green: 0.025, blue: 0.105),
                                    Color(red: 0.018, green: 0.025, blue: 0.065),
                                    Color(red: 0.015, green: 0.02, blue: 0.045)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            RadialGradient(colors: [Color.purple.opacity(0.14), .clear],
                           center: .center, startRadius: 5, endRadius: 310)
                .ignoresSafeArea()
            SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.allowsTransparency])
                .ignoresSafeArea()
                .accessibilityLabel("Orbit game")
                .accessibilityHint("Double tap to reverse orbital direction and avoid hazards.")
                .accessibilityValue("Score \(session.score)")
                .accessibilityHidden(session.state == .gameOver)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { scene.tap() }

            if session.state != .gameOver {
                VStack(spacing: 8) {
                    Text(GameType.orbit.displayName.uppercased())
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.54))
                    Text("\(session.score)")
                        .font(.system(size: 64, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: session.score)
                        .accessibilityIdentifier("liveScore")
                    if session.isNewBest || session.targetBest > 0 {
                        Text(session.isNewBest ? "NEW HIGH SCORE" : "HIGH  \(session.targetBest)")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(2)
                            .foregroundStyle(session.isNewBest
                                             ? Color(red: 0.86, green: 0.72, blue: 1)
                                             : .white.opacity(0.4))
                    }
                    Spacer()
                    instruction
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

    @ViewBuilder
    private var instruction: some View {
        if session.state == .ready {
            Text("TAP TO START")
                .accessibilityIdentifier("orbitInstruction")
                .modifier(OrbitInstructionStyle())
        } else if session.state == .playing && !session.hasReversed {
            Text("TAP TO REVERSE")
                .accessibilityIdentifier("orbitInstruction")
                .modifier(OrbitInstructionStyle())
        }
    }

    private func updateSwitchConfirmationRequirement() {
        let hasUnsavedRun = session.state != .gameOver || session.resultStage == .initials
        switchConfirmationRequirementChanged(hasUnsavedRun)
    }
}

private struct OrbitInstructionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .tracking(3)
            .foregroundStyle(.white.opacity(0.64))
            .padding(.bottom, 30)
    }
}
