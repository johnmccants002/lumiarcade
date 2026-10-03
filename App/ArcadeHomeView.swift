import SwiftUI

struct ArcadeHomeView: View {
    @ObservedObject var model: FullAppModel
    let play: (GameType) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if let recent = model.lastPlayedGame {
                        sectionTitle("CONTINUE PLAYING")
                        GameCard(game: recent, highScore: model.highScore(for: recent), compact: true) {
                            play(recent)
                        }
                    }

                    sectionTitle("ALL GAMES")
                    ForEach(GameType.allCases) { game in
                        GameCard(game: game, highScore: model.highScore(for: game)) {
                            play(game)
                        }
                    }

                    if model.isLoading {
                        HStack { Spacer(); ProgressView("Loading scores…"); Spacer() }
                            .padding(.vertical, 12)
                    } else if let error = model.loadError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(20)
            }
            .background(ArcadeTheme.background.ignoresSafeArea())
            .navigationTitle(Product.displayName)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(2.4)
            .foregroundStyle(.white.opacity(0.55))
    }
}

private struct GameCard: View {
    let game: GameType
    let highScore: Int
    var compact = false
    let play: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 18) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: game.systemImageName)
                    .font(.system(size: compact ? 24 : 30, weight: .medium))
                    .foregroundStyle(ArcadeTheme.accent(for: game))
                    .frame(width: compact ? 48 : 58, height: compact ? 48 : 58)
                    .background(ArcadeTheme.accent(for: game).opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) {
                    Text(game.gameNumber)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.42))
                    Text(game.displayName)
                        .font(.title2.weight(.semibold))
                    if !compact {
                        Text(game.summary)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HIGH SCORE")
                        .font(.system(size: 9, weight: .medium)).tracking(1.5)
                        .foregroundStyle(.white.opacity(0.42))
                    Text(highScore == 0 ? "—" : "\(highScore)")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                Button("PLAY", action: play)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .buttonStyle(.borderedProminent)
                    .tint(ArcadeTheme.accent(for: game))
                    .foregroundStyle(Color(red: 0.025, green: 0.045, blue: 0.08))
                    .accessibilityIdentifier("play-\(game.rawValue)")
            }
        }
        .padding(compact ? 16 : 20)
        .background(ArcadeTheme.card, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(ArcadeTheme.accent(for: game).opacity(0.18), lineWidth: 1)
        }
    }
}
