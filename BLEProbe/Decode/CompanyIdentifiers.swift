import Foundation

/// A working subset of the Bluetooth SIG "Company Identifiers" registry — the
/// 16-bit IDs that lead manufacturer-specific advertisement data. This is the
/// long tail you'll actually bump into; extend it from the official SIG YAML
/// (assigned_numbers/company_identifiers) whenever you meet an unknown one.
enum CompanyIdentifiers {
    static func name(for id: UInt16) -> String {
        table[id] ?? String(format: "Unknown (0x%04X)", id)
    }

    static let table: [UInt16: String] = [
        0x004C: "Apple, Inc.",
        0x0006: "Microsoft",
        0x0075: "Samsung Electronics",
        0x00E0: "Google",
        0x0059: "Nordic Semiconductor",
        0x000D: "Texas Instruments",
        0x0157: "Anhui Huami (Amazfit)",
        0x0171: "Amazon",
        0x0087: "Garmin",
        0x038F: "Xiaomi",
        0x05A7: "Sonos",
        0x0499: "Ruuvi Innovations",
        0x004F: "APT (Qualcomm)",
        0x000F: "Broadcom",
        0x0001: "Ericsson Technology",
        0x0002: "Intel Corp.",
        0x0003: "IBM Corp.",
        0x000A: "Cambridge Silicon Radio (Qualcomm)",
        0x0030: "ST Microelectronics",
        0x0118: "Tile, Inc.",
        0x015D: "Estimote",
        0x0105: "GN Netcom (Jabra)",
        0x0A12: "Chipolo",
        0x0646: "Logitech",
        0x0B36: "Govee",
        0x072F: "DexCom, Inc.",
        0x08E7: "Oura Health",
        0x0A75: "Whoop",
        0x0141: "Fitbit",
        0x0131: "Cypress Semiconductor",
        0x02E5: "Espressif (ESP32)",
        0x0D01: "Flipper Devices",
    ]
}
