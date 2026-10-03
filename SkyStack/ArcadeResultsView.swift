import SwiftUI

struct ArcadeResultsView: View {
    @ObservedObject var session: ArcadeGameSession
    let restart: () -> Void
    @AccessibilityFocusState private var focusedHeading: Bool

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 14) {
                    Text(session.game.displayName.uppercased())
                        .font(.system(size: 11, weight: .medium)).tracking(3)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(heading)
                        .font(.system(size: 12, weight: .semibold)).tracking(2)
                        .foregroundStyle(session.isNewBest ? Color(red: 0.98, green: 0.84, blue: 0.55) : .white)
                        .accessibilityFocused($focusedHeading)
                    Text("\(session.score)")
                        .font(.system(size: 52, weight: .light, design: .rounded))
                        .monospacedDigit().accessibilityIdentifier("finalScore")
                    Text(session.identityLabel)
                        .font(.system(size: 10, weight: .medium)).tracking(1.5)
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("arcadotIdentity")
                    if session.resultStage == .initials {
                        Text("ENTER INITIALS").font(.system(size: 11, weight: .medium)).tracking(2)
                        ArcadeInitialsPicker(selection: $session.initials)
                            .disabled(session.isSaving)
                        Button {
                            Task { await session.saveScore() }
                        } label: {
                            actionLabel(session.isSaving ? "SAVING…" : "SAVE SCORE")
                        }
                        .disabled(session.isSaving)
                        .accessibilityIdentifier("saveScore")
                        if let error = session.saveError {
                            Text(error).font(.caption).multilineTextAlignment(.center)
                            Button("Continue without saving") { session.continueWithoutSaving() }
                                .font(.caption)
                        }
                    } else {
                        leaderboard
                        Button(action: restart) { actionLabel("PLAY AGAIN") }
                            .accessibilityIdentifier("playAgain")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear { focusedHeading = true }
        .onChange(of: session.resultStage) { _, _ in focusedHeading = true }
    }

    private var heading: String {
        if session.resultStage == .initials {
            return session.isNewBest ? "NEW HIGH SCORE!" : "TOP FIVE SCORE!"
        }
        return "SCORE"
    }

    private var leaderboard: some View {
        VStack(spacing: 9) {
            Text("HIGH SCORES").font(.system(size: 11, weight: .semibold)).tracking(2)
                .padding(.bottom, 3)
            if let error = session.saveError {
                Text(error).font(.caption).multilineTextAlignment(.center)
            }
            if session.leaderboard.isEmpty && session.saveError == nil {
                Text("No scores saved yet.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
            }
            ForEach(Array(session.leaderboard.enumerated()), id: \.element.id) { index, entry in
                HStack {
                    Text("\(index + 1).").foregroundStyle(.white.opacity(0.4)).frame(width: 24, alignment: .leading)
                    Text(entry.initials).tracking(3)
                    Spacer()
                    Text("\(entry.score)").monospacedDigit()
                }
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rank \(index + 1), \(entry.initials), \(entry.score) points")
                .accessibilityIdentifier("leaderboardRow\(index)")
            }
        }
        .frame(maxWidth: 250)
        .padding(.vertical, 8)
    }

    private func actionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold)).tracking(2)
            .foregroundStyle(Color(red: 0.04, green: 0.08, blue: 0.11))
            .padding(.horizontal, 30).frame(minHeight: 50)
            .background(.white, in: Capsule())
    }
}
