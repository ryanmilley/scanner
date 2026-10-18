import SwiftUI
import CoreBluetooth

struct PeripheralDetailView: View {
    @EnvironmentObject var bt: BluetoothManager
    let peripheralID: UUID

    private var peripheral: DiscoveredPeripheral? {
        bt.peripherals.first { $0.id == peripheralID }
    }
    private var isActive: Bool { bt.connectedPeripheralID == peripheralID }

    var body: some View {
        List {
            if let p = peripheral {
                advertisementSection(p)
            }
            connectionSection
            if isActive && !bt.services.isEmpty {
                gattSection
            }
        }
        .navigationTitle(peripheral?.displayName ?? "Device")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Advertisement

    @ViewBuilder
    private func advertisementSection(_ p: DiscoveredPeripheral) -> some View {
        Section("Signal") {
            row("RSSI", "\(p.rssi) dBm")
            if let tx = p.advertisement.txPowerLevel { row("Tx Power", "\(tx) dBm") }
            row("Identifier", p.id.uuidString, mono: true)
            row("Connectable", p.connectable ? "yes" : "no")
        }

        if let name = p.advertisement.localName {
            Section("Local Name") { Text(name) }
        }

        if let company = p.advertisement.companyName {
            Section("Manufacturer") {
                row("Company", company)
                if let id = p.advertisement.companyID {
                    row("Company ID", String(format: "0x%04X", id), mono: true)
                }
                ForEach(p.advertisement.manufacturerDecoded) { f in
                    row(f.label, f.value, mono: f.label.contains("raw") || f.label.contains("UUID"))
                }
                if let raw = p.advertisement.manufacturerData {
                    row("Raw", raw.hexString, mono: true)
                }
            }
        }

        if !p.advertisement.serviceUUIDs.isEmpty {
            Section("Advertised Services") {
                ForEach(p.advertisement.serviceUUIDs, id: \.self) { uuid in
                    VStack(alignment: .leading) {
                        Text(AssignedNumbers.serviceName(for: uuid) ?? "Service")
                        Text(uuid.uuidString).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
        }

        if !p.advertisement.serviceData.isEmpty {
            Section("Service Data") {
                ForEach(Array(p.advertisement.serviceData.keys), id: \.self) { key in
                    VStack(alignment: .leading) {
                        Text(AssignedNumbers.serviceName(for: key) ?? key.uuidString)
                            .font(.caption.monospaced())
                        Text(p.advertisement.serviceData[key]?.hexString ?? "")
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Connection

    @ViewBuilder
    private var connectionSection: some View {
        Section("Connection") {
            if isActive {
                switch bt.connectionState {
                case .connected:
                    Label("Connected", systemImage: "link").foregroundStyle(.green)
                case .connecting:
                    Label("Connecting…", systemImage: "ellipsis").foregroundStyle(.orange)
                default:
                    Label("Disconnected", systemImage: "link.badge.plus")
                }
                Button("Disconnect", role: .destructive) { bt.disconnectActive() }
            } else {
                Button {
                    bt.connect(peripheralID)
                } label: {
                    Label("Connect & Explore GATT", systemImage: "arrow.right.circle")
                }
                .disabled(!(peripheral?.connectable ?? true))
            }
        }
    }

    // MARK: GATT tree

    private var gattSection: some View {
        Section("GATT Services (\(bt.services.count))") {
            ForEach(bt.services) { svc in
                DisclosureGroup {
                    ForEach(svc.characteristics) { ch in
                        NavigationLink {
                            CharacteristicView(serviceID: svc.id, characteristicID: ch.id)
                        } label: {
                            CharacteristicRow(characteristic: ch)
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(svc.name).font(.body.weight(.medium))
                        Text(svc.uuid.uuidString).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func row(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .font(mono ? .caption.monospaced() : .body)
                .textSelection(.enabled)
        }
    }
}

struct CharacteristicRow: View {
    let characteristic: GATTCharacteristic
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(characteristic.name).font(.subheadline.weight(.medium))
            HStack(spacing: 4) {
                ForEach(characteristic.propertyList, id: \.self) { prop in
                    Tag(text: prop, tint: tint(for: prop))
                }
            }
        }
    }
    private func tint(for prop: String) -> Color {
        switch prop {
        case "read": return .blue
        case "write", "writeNoRsp": return .orange
        case "notify", "indicate": return .purple
        default: return .secondary
        }
    }
}
