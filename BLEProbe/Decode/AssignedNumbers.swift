import Foundation
import CoreBluetooth

/// Human-readable names for the Bluetooth SIG 16-bit assigned numbers — GATT
/// services, characteristics, and descriptors. Covers the standard set you meet
/// most; extend from the SIG assigned_numbers repo as needed. Vendor-specific
/// 128-bit UUIDs fall through to their raw string.
enum AssignedNumbers {

    /// Normalize a CBUUID to its short 16-bit hex (e.g. "180F") when it sits in
    /// the Bluetooth base UUID range, otherwise the full 128-bit string.
    private static func key(_ uuid: CBUUID) -> String {
        uuid.uuidString.uppercased()
    }

    static func serviceName(for uuid: CBUUID) -> String? { services[key(uuid)] }
    static func characteristicName(for uuid: CBUUID) -> String? { characteristics[key(uuid)] }
    static func descriptorName(for uuid: CBUUID) -> String? { descriptors[key(uuid)] }

    static let services: [String: String] = [
        "1800": "Generic Access",
        "1801": "Generic Attribute",
        "1802": "Immediate Alert",
        "1803": "Link Loss",
        "1804": "Tx Power",
        "1805": "Current Time",
        "1808": "Glucose",
        "1809": "Health Thermometer",
        "180A": "Device Information",
        "180D": "Heart Rate",
        "180F": "Battery",
        "1810": "Blood Pressure",
        "1812": "Human Interface Device",
        "1814": "Running Speed and Cadence",
        "1816": "Cycling Speed and Cadence",
        "1818": "Cycling Power",
        "1819": "Location and Navigation",
        "181A": "Environmental Sensing",
        "181B": "Body Composition",
        "181C": "User Data",
        "181D": "Weight Scale",
        "1826": "Fitness Machine",
        "FD6F": "Exposure Notification (contact tracing)",
        "FDEF": "Apple Nearby",
        "FEAA": "Eddystone (Google)",
        "FE9F": "Google",
    ]

    static let characteristics: [String: String] = [
        "2A00": "Device Name",
        "2A01": "Appearance",
        "2A04": "Preferred Connection Parameters",
        "2A05": "Service Changed",
        "2A19": "Battery Level",
        "2A23": "System ID",
        "2A24": "Model Number",
        "2A25": "Serial Number",
        "2A26": "Firmware Revision",
        "2A27": "Hardware Revision",
        "2A28": "Software Revision",
        "2A29": "Manufacturer Name",
        "2A2B": "Current Time",
        "2A37": "Heart Rate Measurement",
        "2A38": "Body Sensor Location",
        "2A39": "Heart Rate Control Point",
        "2A6D": "Pressure",
        "2A6E": "Temperature",
        "2A6F": "Humidity",
        "2A63": "Cycling Power Measurement",
        "2A53": "RSC Measurement",
        "2A5B": "CSC Measurement",
    ]

    static let descriptors: [String: String] = [
        "2900": "Characteristic Extended Properties",
        "2901": "Characteristic User Description",
        "2902": "Client Characteristic Configuration (CCCD)",
        "2903": "Server Characteristic Configuration",
        "2904": "Presentation Format",
        "2905": "Aggregate Format",
    ]
}
