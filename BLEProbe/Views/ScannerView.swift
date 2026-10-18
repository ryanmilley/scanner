import SwiftUI
import CoreBluetooth

struct ScannerView: View {
    @EnvironmentObject var bt: BluetoothManager

    var body: some View {
        NavigationStack {
            Group {
                if bt.state == .poweredOn {
                    peripheralList
                } else {
                    statusScreen
                }
            }
            .navigationTitle("Probe")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { LogView() } label: { Image(systemName: "list.bullet.rectangle") }
                }
                ToolbarItem(placement: .topBarTrailing) { scanButton }
            }
        }
    }

    private var scanButton: some View {
        Button {
            bt.isScanning ? bt.stopScan() : bt.startScan()
        } label: {
            Text(bt.isScanning ? "Stop" : "Scan")
                .fontWeight(.semibold)
        }
        .disabled(bt.state != .poweredOn)
    }

    private var peripheralList: some View {
        List {
            Section {
                Toggle("Firehose (allow duplicates)", isOn: $bt.allowDuplicates)
                    .font(.footnote)
                    .disabled(bt.isScanning)
                HStack {
                    Text("Min RSSI").font(.footnote)
                    Slider(value: Binding(
                        get: { Double(bt.minimumRSSI) },
                        set: { bt.minimumRSSI = Int($0) }
                    ), in: -100...(-30), step: 1)
                    Text("\(bt.minimumRSSI)").font(.footnote.monospacedDigit())
                }
            }

            Section {
                ForEach(bt.peripherals) { p in
                    NavigationLink { PeripheralDetailView(peripheralID: p.id) } label: {
                        PeripheralRow(peripheral: p)
                    }
                }
            } header: {
                Text("\(bt.peripherals.count) device\(bt.peripherals.count == 1 ? "" : "s")")
            }
        }
    }

    private var statusScreen: some View {
        ContentUnavailableView {
            Label(stateTitle, systemImage: "antenna.radiowaves.left.and.right.slash")
        } description: {
            Text(stateMessage)
        }
    }

    private var stateTitle: String {
        switch bt.state {
        case .poweredOff:   return "Bluetooth Off"
        case .unauthorized: return "Permission Needed"
        case .unsupported:  return "Not Supported"
        case .resetting:    return "Resetting…"
        default:            return "Starting Up…"
        }
    }

    private var stateMessage: String {
        switch bt.state {
        case .poweredOff:   return "Turn Bluetooth on in Control Center or Settings."
        case .unauthorized: return "Allow Bluetooth for Probe in Settings › Probe."
        case .unsupported:  return "This device has no BLE radio."
        default:            return "Waiting for the Bluetooth stack."
        }
    }
}

struct PeripheralRow: View {
    let peripheral: DiscoveredPeripheral

    var body: some View {
        HStack(spacing: 12) {
            SignalBars(rssi: peripheral.rssi)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(peripheral.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let hint = peripheral.advertisement.deviceHint {
                        Tag(text: hint)
                    }
                    if peripheral.connectable {
                        Tag(text: "connectable", tint: .green)
                    }
                    if !peripheral.advertisement.serviceUUIDs.isEmpty {
                        Tag(text: "\(peripheral.advertisement.serviceUUIDs.count) svc")
                    }
                }
            }
            Spacer()
            Text("\(peripheral.rssi)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct SignalBars: View {
    let rssi: Int
    private var level: Int {
        switch rssi {
        case (-55)...0:    return 4
        case (-67)..<(-55): return 3
        case (-80)..<(-67): return 2
        case (-95)..<(-80): return 1
        default:           return 0
        }
    }
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < level ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 4, height: CGFloat(6 + i * 4))
            }
        }
    }
}

struct Tag: View {
    let text: String
    var tint: Color = .secondary
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}
