import Foundation

/// Decoder for Apple's manufacturer payload (company ID 0x004C). Apple packs a
/// sequence of TLV messages — "Continuity" — into its advertisements: iBeacon,
/// Handoff, Nearby Info/Action, AirPods proximity pairing, Find My, and more.
///
/// The frame formats are community-reverse-engineered, not published by Apple,
/// so well-established fields (iBeacon) are decoded fully, and the rest are
/// named with their raw bytes plus clearly-labelled best-effort hints. Nothing
/// here needs private API — it's all in the public advertisement bytes.
enum AppleContinuityDecoder {

    // Continuity message type codes.
    private static let typeNames: [UInt8: String] = [
        0x02: "iBeacon",
        0x05: "AirDrop",
        0x06: "HomeKit",
        0x07: "Proximity Pairing (AirPods)",
        0x08: "Hey Siri",
        0x09: "AirPlay Target",
        0x0A: "Magic Switch (Watch)",
        0x0B: "Watch Connectivity",
        0x0C: "Handoff",
        0x0D: "Tethering Target",
        0x0E: "Tethering Source",
        0x0F: "Nearby Action",
        0x10: "Nearby Info",
        0x12: "Find My",
    ]

    /// `payload` is the manufacturer data with the 2-byte company ID already stripped.
    static func decode(_ payload: Data) -> [DecodedField] {
        var fields: [DecodedField] = []
        let bytes = [UInt8](payload)
        var i = 0

        while i + 1 < bytes.count {
            let type = bytes[i]
            let len = Int(bytes[i + 1])
            let start = i + 2
            let end = min(start + len, bytes.count)
            guard start <= end else { break }
            let value = Array(bytes[start..<end])

            let typeName = typeNames[type] ?? String(format: "Type 0x%02X", type)
            fields.append(DecodedField(label: "Message", value: typeName))
            fields.append(contentsOf: decodeMessage(type: type, value: value))

            i = end
        }

        if fields.isEmpty {
            fields.append(DecodedField(label: "Apple payload", value: payload.hexString))
        }
        return fields
    }

    private static func decodeMessage(type: UInt8, value: [UInt8]) -> [DecodedField] {
        switch type {
        case 0x02: return decodeIBeacon(value)
        case 0x07: return decodeProximityPairing(value)
        case 0x10: return decodeNearbyInfo(value)
        case 0x0C: return decodeHandoff(value)
        case 0x12: return decodeFindMy(value)
        default:
            return [DecodedField(label: "  raw", value: Data(value).hexString)]
        }
    }

    // iBeacon — the one fully-specified frame. 16-byte UUID + major + minor + power.
    private static func decodeIBeacon(_ v: [UInt8]) -> [DecodedField] {
        guard v.count >= 21 else { return [DecodedField(label: "  raw", value: Data(v).hexString)] }
        let uuidBytes = Array(v[0..<16])
        let uuid = uuidBytes.map { String(format: "%02X", $0) }.joined()
        let formatted = "\(uuid.prefix(8))-\(uuid.dropFirst(8).prefix(4))-\(uuid.dropFirst(12).prefix(4))-\(uuid.dropFirst(16).prefix(4))-\(uuid.dropFirst(20))"
        let major = (UInt16(v[16]) << 8) | UInt16(v[17])
        let minor = (UInt16(v[18]) << 8) | UInt16(v[19])
        let power = Int8(bitPattern: v[20])
        return [
            DecodedField(label: "  UUID", value: formatted),
            DecodedField(label: "  Major", value: "\(major)"),
            DecodedField(label: "  Minor", value: "\(minor)"),
            DecodedField(label: "  Measured power", value: "\(power) dBm @ 1m"),
        ]
    }

    // AirPods / proximity pairing. Battery + lid state are model-dependent and
    // community-derived, so flagged approximate.
    private static func decodeProximityPairing(_ v: [UInt8]) -> [DecodedField] {
        var out: [DecodedField] = []
        if v.count >= 4 {
            let model = (UInt16(v[2]) << 8) | UInt16(v[3])
            out.append(DecodedField(label: "  Device model", value: String(format: "0x%04X", model)))
        }
        if v.count >= 6 {
            // Nibbles commonly map to battery; exact layout varies by model.
            let right = v[5] >> 4, left = v[5] & 0x0F
            out.append(DecodedField(label: "  Battery (approx)", value: "L nibble \(left), R nibble \(right)"))
        }
        out.append(DecodedField(label: "  raw", value: Data(v).hexString))
        return out
    }

    // Nearby Info — the ubiquitous "what is this iPhone doing" beacon.
    private static func decodeNearbyInfo(_ v: [UInt8]) -> [DecodedField] {
        guard v.count >= 2 else { return [DecodedField(label: "  raw", value: Data(v).hexString)] }
        let statusFlags = v[0] >> 4
        let actionCode = v[0] & 0x0F
        let action: String
        switch actionCode {
        case 0x00: action = "Activity level unknown"
        case 0x01: action = "Activity reporting disabled"
        case 0x03: action = "Idle"
        case 0x05: action = "Audio playing (screen off)"
        case 0x07: action = "Active user (screen on)"
        case 0x09: action = "Screen on + video"
        case 0x0A: action = "Watch on wrist, unlocked"
        case 0x0B: action = "Recent user activity"
        case 0x0D: action = "Phone/FaceTime call"
        default:   action = String(format: "Code 0x%02X", actionCode)
        }
        return [
            DecodedField(label: "  Activity", value: action),
            DecodedField(label: "  Status flags", value: String(format: "0x%X", statusFlags)),
            DecodedField(label: "  raw", value: Data(v).hexString),
        ]
    }

    private static func decodeHandoff(_ v: [UInt8]) -> [DecodedField] {
        guard v.count >= 2 else { return [DecodedField(label: "  raw", value: Data(v).hexString)] }
        let clipboard = v[0]
        let seq = (UInt16(v[1]) << 8) | UInt16(v.count > 2 ? v[2] : 0)
        return [
            DecodedField(label: "  Clipboard flag", value: String(format: "0x%02X", clipboard)),
            DecodedField(label: "  Sequence", value: "\(seq)"),
            DecodedField(label: "  Encrypted payload", value: Data(v).hexString),
        ]
    }

    // Find My — short frame (nearby owner) or full frame (separated, broadcasting key).
    private static func decodeFindMy(_ v: [UInt8]) -> [DecodedField] {
        var out: [DecodedField] = []
        let frame = v.count >= 25 ? "Full (separated, offline-finding)" : "Short (owner nearby)"
        out.append(DecodedField(label: "  Frame", value: frame))
        if let status = v.first {
            out.append(DecodedField(label: "  Status", value: String(format: "0x%02X", status)))
        }
        out.append(DecodedField(label: "  raw", value: Data(v).hexString))
        return out
    }
}
