import SwiftUI

struct ArcadeInitialsPicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 20) {
            ForEach(0..<3) { column in
                VStack(spacing: 0) {
                    Button { cycle(column, 1) } label: {
                        Image(systemName: "chevron.up").frame(width: 52, height: 44)
                    }
                    .accessibilityLabel("Next character \(column + 1)")
                    .accessibilityIdentifier("initialUp\(column)")
                    Text(String(letters[column]))
                        .font(.system(size: 34, weight: .medium, design: .monospaced))
                        .frame(width: 52, height: 44)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("Initial \(column + 1)")
                        .accessibilityValue(String(letters[column]))
                        .accessibilityIdentifier("initial\(column)")
                        .accessibilityAdjustableAction { direction in
                            switch direction {
                            case .increment: cycle(column, 1)
                            case .decrement: cycle(column, -1)
                            @unknown default: break
                            }
                        }
                    Button { cycle(column, -1) } label: {
                        Image(systemName: "chevron.down").frame(width: 52, height: 44)
                    }
                    .accessibilityLabel("Previous character \(column + 1)")
                    .accessibilityIdentifier("initialDown\(column)")
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private var letters: [Character] { Array(ArcadeInitials.isValid(selection) ? selection : "AAA") }

    private func cycle(_ column: Int, _ direction: Int) {
        selection = ArcadeInitials.cycling(selection, column: column, direction: direction)
    }
}
