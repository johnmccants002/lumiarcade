import SwiftUI

struct PlayerProfileView: View {
    @ObservedObject var model: FullAppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text(model.initials)
                            .font(.system(size: 54, weight: .light, design: .monospaced))
                            .tracking(7)
                        Text("PLAYER INITIALS")
                            .font(.system(size: 10, weight: .semibold)).tracking(2)
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    .padding(.top, 8)

                    VStack(spacing: 12) {
                        Text("EDIT INITIALS")
                            .font(.system(size: 11, weight: .semibold)).tracking(2)
                            .foregroundStyle(.white.opacity(0.58))
                        ArcadeInitialsPicker(selection: $model.initials)
                        Button("SAVE INITIALS") { model.saveInitials() }
                            .font(.system(size: 12, weight: .bold)).tracking(1.5)
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
                            .foregroundStyle(ArcadeTheme.background)
                        if let message = model.profileMessage {
                            Text(message).font(.footnote).foregroundStyle(.white.opacity(0.65))
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(ArcadeTheme.card, in: RoundedRectangle(cornerRadius: 24))

                    VStack(spacing: 0) {
                        ProfileStatRow(label: "Games Played", value: "\(model.gamesPlayed)")
                        Divider().overlay(.white.opacity(0.08))
                        ForEach(GameType.allCases) { game in
                            ProfileStatRow(label: "\(game.displayName) High Score",
                                           value: model.highScore(for: game) == 0 ? "—" : "\(model.highScore(for: game))")
                            if game != GameType.allCases.last {
                                Divider().overlay(.white.opacity(0.08))
                            }
                        }
                    }
                    .background(ArcadeTheme.card, in: RoundedRectangle(cornerRadius: 24))
                }
                .padding(20)
            }
            .background(ArcadeTheme.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct ProfileStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.white.opacity(0.68))
            Spacer()
            Text(value).font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 58)
    }
}
