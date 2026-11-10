import SwiftUI
import WatchKit

/// System volume control for audio playing on the watch (Digital Crown).
///
/// Apple: "You cannot access or change the volume programmatically in your app."
/// The supported route is WKInterfaceVolumeControl, created for SwiftUI with
/// init(origin:) and wrapped in WKInterfaceObjectRepresentable:
///   https://developer.apple.com/documentation/watchkit/wkinterfacevolumecontrol
///   https://developer.apple.com/documentation/watchkit/wkinterfacevolumecontrol/init(origin:)
struct VolumeControlView: WKInterfaceObjectRepresentable {
    /// When true, the control takes Digital Crown focus so turning the crown changes volume.
    var wantsCrownFocus: Bool

    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        WKInterfaceVolumeControl(origin: .local)
    }

    func updateWKInterfaceObject(_ control: WKInterfaceVolumeControl, context: Context) {
        if wantsCrownFocus {
            // Defer so the control is in the hierarchy before it takes focus.
            DispatchQueue.main.async {
                control.focus()
            }
        }
    }
}
