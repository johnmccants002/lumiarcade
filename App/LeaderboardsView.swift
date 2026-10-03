import SwiftUI

struct LeaderboardsView: View {
    @ObservedObject var model: FullAppModel
    @State private var selectedGame: GameType = .skyStack

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Picker("Game", selection: $selectedGame) {
                    ForEach(GameType.allCases) { game in
                        Text(game.displayName).tag(game)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                Group {
                    if model.isLoading && model.leaderboard(for: selectedGame).isEmpty {
                        Spacer()
                        ProgressView("Loading leaderboard…")
                        Spacer()
                    } else if let error = model.loadError {
                        Spacer()
                        ContentUnavailableView {
                            Label("Couldn’t Load Scores", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Try Again") { model.refresh() }
                        }
                        Spacer()
                    } else if model.leaderboard(for: selectedGame).isEmpty {
                        Spacer()
                        ContentUnavailableView("No Scores Yet",
                                               systemImage: selectedGame.systemImageName,
                                               description: Text("Play \(selectedGame.displayName) to start this leaderboard."))
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(Array(model.leaderboard(for: selectedGame).enumerated()), id: \.element.id) { index, score in
                                    LeaderboardRow(rank: index + 1, score: score)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .padding(.top, 8)
            .background(ArcadeTheme.background.ignoresSafeArea())
            .navigationTitle("Leaderboards")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable { model.refresh() }
        }
    }
}

private struct LeaderboardRow: View {
    let rank: Int
    let score: ArcadeScore

    var body: some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(rank == 1 ? 1 : 0.48))
                .frame(width: 28)
            Text(score.initials)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .tracking(3)
            Spacer()
            Text("\(score.score)")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 62)
        .background(ArcadeTheme.card, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(rank), \(score.initials), \(score.score) points")
    }
}
