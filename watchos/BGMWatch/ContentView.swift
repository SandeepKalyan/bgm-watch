import SwiftUI

struct ContentView: View {
    @StateObject private var player = ClipPlayer()

    var body: some View {
        // No ScrollView: it would compete with the volume control for the Digital Crown.
        VStack(spacing: 4) {
            Text(ClipPlayer.clipTitle)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(player.state.rawValue)
                .font(.caption)
                .foregroundColor(stateColor)

            Text("\(player.elapsedSeconds) s")
                .font(.title3)

            Button(action: player.toggle) {
                Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 32, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }

            if let message = player.errorText {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
            }

            VolumeControlView(wantsCrownFocus: player.isPlaying)
                .frame(height: 24)
        }
    }

    private var stateColor: Color {
        switch player.state {
        case .stopped: return .gray
        case .playing: return .green
        case .error: return .red
        }
    }
}
