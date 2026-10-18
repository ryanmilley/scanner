import SwiftUI
import CoreBluetooth

struct CharacteristicView: View {
    @EnvironmentObject var bt: BluetoothManager
    let serviceID: ObjectIdentifier
    let characteristicID: ObjectIdentifier

    @State private var writeText = ""
    @State private var writeAsHex = true
    @State private var withResponse = true

    private var characteristic: GATTCharacteristic? {
        bt.services.first { $0.id == serviceID }?
           .characteristics.first { $0.id == characteristicID }
    }

    var body: some View {
        List {
            if let c = characteristic {
                headerSection(c)
                valueSection(c)
                if c.canRead || c.canNotify { readSection(c) }
                if c.canWrite { writeSection(c) }
                if !c.descriptors.isEmpty { descriptorSection(c) }
            } else {
                Text("Characteristic no longer available.").foregroundStyle(.secondary)
            }
            consoleSection
        }
        .navigationTitle(characteristic?.name ?? "Characteristic")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headerSection(_ c: GATTCharacteristic) -> some View {
        Section {
            LabeledContent("UUID") {
                Text(c.uuid.uuidString).font(.caption.monospaced()).textSelection(.enabled)
            }
            LabeledContent("Properties") {
                Text(c.propertyList.joined(separator: ", ")).font(.caption)
            }
        }
    }

    @ViewBuilder
    private func valueSection(_ c: GATTCharacteristic) -> some View {
        Section("Current Value") {
            if let v = c.value, !v.isEmpty {
                LabeledContent("Hex") { Text(v.hexString).font(.caption.monospaced()).textSelection(.enabled) }
                LabeledContent("ASCII") { Text(v.asciiString).font(.caption.monospaced()).textSelection(.enabled) }
                LabeledContent("Length") { Text("\(v.count) bytes") }
            } else {
                Text("— no value read yet —").foregroundStyle(.secondary)
            }
        }
    }

    private func readSection(_ c: GATTCharacteristic) -> some View {
        Section {
            if c.canRead {
                Button { bt.read(c) } label: { Label("Read", systemImage: "arrow.down.circle") }
            }
            if c.canNotify {
                Toggle(isOn: Binding(
                    get: { c.isNotifying },
                    set: { _ in bt.toggleNotify(c) }
                )) {
                    Label("Subscribe to notifications", systemImage: "bell")
                }
            }
        }
    }

    private func writeSection(_ c: GATTCharacteristic) -> some View {
        Section("Write") {
            Picker("Format", selection: $writeAsHex) {
                Text("Hex").tag(true)
                Text("Text").tag(false)
            }.pickerStyle(.segmented)

            TextField(writeAsHex ? "DE AD BE EF" : "hello", text: $writeText, axis: .vertical)
                .font(.callout.monospaced())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if c.properties.contains(.write) && c.properties.contains(.writeWithoutResponse) {
                Toggle("With response (ack)", isOn: $withResponse)
            }

            Button {
                guard let data = parseWrite() else { return }
                bt.write(data, to: c, withResponse: resolvedWithResponse(c))
            } label: {
                Label("Send", systemImage: "arrow.up.circle.fill")
            }
            .disabled(parseWrite() == nil)

            Text("⚠︎ Writes change device state. Only probe gear you own.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func descriptorSection(_ c: GATTCharacteristic) -> some View {
        Section("Descriptors") {
            ForEach(c.descriptors) { d in
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.name).font(.subheadline)
                    Text(d.uuid.uuidString).font(.caption.monospaced()).foregroundStyle(.secondary)
                    if let v = d.value { Text(v).font(.caption.monospaced()) }
                }
            }
        }
    }

    private var consoleSection: some View {
        Section("Activity") {
            ForEach(bt.log.suffix(15).reversed()) { entry in
                LogRow(entry: entry)
            }
        }
    }

    // MARK: Write parsing

    private func resolvedWithResponse(_ c: GATTCharacteristic) -> Bool {
        if c.properties.contains(.write) && c.properties.contains(.writeWithoutResponse) {
            return withResponse
        }
        return c.properties.contains(.write)
    }

    private func parseWrite() -> Data? {
        let trimmed = writeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if writeAsHex {
            let cleaned = trimmed.replacingOccurrences(of: " ", with: "")
                                 .replacingOccurrences(of: "0x", with: "")
            guard cleaned.count % 2 == 0 else { return nil }
            var data = Data()
            var idx = cleaned.startIndex
            while idx < cleaned.endIndex {
                let next = cleaned.index(idx, offsetBy: 2)
                guard let byte = UInt8(cleaned[idx..<next], radix: 16) else { return nil }
                data.append(byte)
                idx = next
            }
            return data
        } else {
            return trimmed.data(using: .utf8)
        }
    }
}
