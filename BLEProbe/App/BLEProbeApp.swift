import SwiftUI

@main
struct BLEProbeApp: App {
    // Instantiate the manager at launch so Core Bluetooth state restoration can
    // hand our session back on a background relaunch.
    @StateObject private var bt = BluetoothManager.shared

    var body: some Scene {
        WindowGroup {
            ScannerView()
                .environmentObject(bt)
        }
    }
}
