import Foundation
import CoreBluetooth

// MARK: - Discovered peripheral (advertisement-level snapshot)

/// A device seen in a scan. `id` is iOS's per-app randomized identifier for the
/// peripheral — NOT its hardware MAC, which third-party apps never get.
struct DiscoveredPeripheral: Identifiable {
    let id: UUID
    var name: String?
    var rssiHistory: [Int]          // most-recent last; capped
    var firstSeen: Date
    var lastSeen: Date
    var advertisement: ParsedAdvertisement
    var connectable: Bool

    var rssi: Int { rssiHistory.last ?? 0 }

    /// A best-effort display name: advertised local name, else a decoded
    /// device hint (e.g. "Apple device"), else the short identifier.
    var displayName: String {
        if let n = name, !n.isEmpty { return n }
        if let hint = advertisement.deviceHint { return hint }
        return "Unknown · \(id.uuidString.prefix(8))"
    }
}

// MARK: - Parsed advertisement

struct ParsedAdvertisement {
    var localName: String?
    var serviceUUIDs: [CBUUID] = []
    var overflowServiceUUIDs: [CBUUID] = []
    var solicitedServiceUUIDs: [CBUUID] = []
    var serviceData: [CBUUID: Data] = [:]
    var manufacturerData: Data?
    var txPowerLevel: Int?

    /// Company ID from the first two little-endian bytes of manufacturer data.
    var companyID: UInt16? {
        guard let d = manufacturerData, d.count >= 2 else { return nil }
        return UInt16(d[d.startIndex]) | (UInt16(d[d.startIndex + 1]) << 8)
    }

    var companyName: String? {
        companyID.flatMap { CompanyIdentifiers.name(for: $0) }
    }

    /// Decoded, human-readable manufacturer payload (Apple Continuity etc.).
    var manufacturerDecoded: [DecodedField] {
        guard let company = companyID, let data = manufacturerData else { return [] }
        let payload = data.subdata(in: data.index(data.startIndex, offsetBy: 2)..<data.endIndex)
        switch company {
        case 0x004C: return AppleContinuityDecoder.decode(payload)
        default:     return []
        }
    }

    /// A short hint about what kind of device this is, from whatever we decoded.
    var deviceHint: String? {
        if let c = companyName { return c }
        if !serviceUUIDs.isEmpty,
           let known = serviceUUIDs.compactMap({ AssignedNumbers.serviceName(for: $0) }).first {
            return known
        }
        return nil
    }
}

/// A decoded label/value pair surfaced in the UI.
struct DecodedField: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

// MARK: - GATT snapshot models (derived from the live CBPeripheral graph)

struct GATTService: Identifiable {
    let id: ObjectIdentifier
    let uuid: CBUUID
    let isPrimary: Bool
    let cbService: CBService
    var characteristics: [GATTCharacteristic]

    var name: String { AssignedNumbers.serviceName(for: uuid) ?? uuid.uuidString }
}

struct GATTCharacteristic: Identifiable {
    let id: ObjectIdentifier
    let uuid: CBUUID
    let properties: CBCharacteristicProperties
    let cbCharacteristic: CBCharacteristic
    var value: Data?
    var isNotifying: Bool
    var descriptors: [GATTDescriptor]

    var name: String { AssignedNumbers.characteristicName(for: uuid) ?? uuid.uuidString }

    var propertyList: [String] {
        var out: [String] = []
        if properties.contains(.broadcast)                { out.append("broadcast") }
        if properties.contains(.read)                     { out.append("read") }
        if properties.contains(.writeWithoutResponse)     { out.append("writeNoRsp") }
        if properties.contains(.write)                    { out.append("write") }
        if properties.contains(.notify)                   { out.append("notify") }
        if properties.contains(.indicate)                 { out.append("indicate") }
        if properties.contains(.authenticatedSignedWrites){ out.append("signedWrite") }
        if properties.contains(.extendedProperties)       { out.append("extended") }
        return out
    }

    var canRead: Bool   { properties.contains(.read) }
    var canWrite: Bool  { properties.contains(.write) || properties.contains(.writeWithoutResponse) }
    var canNotify: Bool { properties.contains(.notify) || properties.contains(.indicate) }
}

struct GATTDescriptor: Identifiable {
    let id: ObjectIdentifier
    let uuid: CBUUID
    let cbDescriptor: CBDescriptor
    var value: String?

    var name: String { AssignedNumbers.descriptorName(for: uuid) ?? uuid.uuidString }
}

// MARK: - Activity log

struct LogEntry: Identifiable {
    enum Kind { case info, read, write, notify, error }
    let id = UUID()
    let time = Date()
    let kind: Kind
    let text: String
}

// MARK: - Data formatting helpers

extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
    /// Printable ASCII rendering, non-printables shown as ".".
    var asciiString: String {
        var s = ""
        for b in self { s.append((32...126).contains(b) ? Character(UnicodeScalar(b)) : ".") }
        return s
    }
}
