import Foundation
import CoreBluetooth
import Combine

/// Central hub for everything Bluetooth. Owns the single `CBCentralManager`,
/// runs the scan, tracks discovered peripherals, and drives one active
/// connection's GATT exploration. Delegate callbacks arrive on the main queue
/// (we pass `queue: nil`), so publishing to SwiftUI is safe without hopping.
final class BluetoothManager: NSObject, ObservableObject {

    /// Created once at launch so iOS can hand us back state on a background relaunch.
    static let shared = BluetoothManager()

    // Scanning / discovery
    @Published private(set) var state: CBManagerState = .unknown
    @Published private(set) var isScanning = false
    @Published private(set) var peripherals: [DiscoveredPeripheral] = []
    @Published var allowDuplicates = true      // firehose mode (foreground only)
    @Published var minimumRSSI: Int = -100     // UI filter

    // Active connection
    @Published private(set) var connectionState: CBPeripheralState = .disconnected
    @Published private(set) var connectedPeripheralID: UUID?
    @Published private(set) var services: [GATTService] = []
    @Published private(set) var log: [LogEntry] = []

    private var central: CBCentralManager!
    private var store: [UUID: DiscoveredPeripheral] = [:]
    private var cbByID: [UUID: CBPeripheral] = [:]
    private var active: CBPeripheral?
    private var republishTimer: Timer?

    private static let restoreID = "com.ryanmilley.bleprobe.central"

    private override init() {
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: Self.restoreID,
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
        )
    }

    // MARK: - Scan control

    func startScan() {
        guard central.state == .poweredOn else { return }
        store.removeAll()
        publishPeripherals()
        central.scanForPeripherals(
            withServices: nil,  // wildcard: every advertising BLE device
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates]
        )
        isScanning = true
        addLog(.info, "Scan started (wildcard, duplicates \(allowDuplicates ? "on" : "off"))")
    }

    func stopScan() {
        central.stopScan()
        isScanning = false
        addLog(.info, "Scan stopped")
    }

    func clear() {
        store.removeAll()
        publishPeripherals()
    }

    // MARK: - Connection control

    func connect(_ id: UUID) {
        guard let p = cbByID[id] else { return }
        disconnectActive()
        active = p
        p.delegate = self
        connectedPeripheralID = id
        services = []
        log = []
        addLog(.info, "Connecting to \(p.name ?? id.uuidString.prefix(8).description)…")
        central.connect(p, options: nil)
    }

    func disconnectActive() {
        if let p = active { central.cancelPeripheralConnection(p) }
    }

    // MARK: - Characteristic operations (the "see what happens" surface)

    func read(_ c: GATTCharacteristic) {
        active?.readValue(for: c.cbCharacteristic)
        addLog(.read, "READ requested · \(c.name)")
    }

    func toggleNotify(_ c: GATTCharacteristic) {
        let newValue = !c.cbCharacteristic.isNotifying
        active?.setNotifyValue(newValue, for: c.cbCharacteristic)
        addLog(.notify, "\(newValue ? "Subscribe" : "Unsubscribe") · \(c.name)")
    }

    func write(_ data: Data, to c: GATTCharacteristic, withResponse: Bool) {
        let type: CBCharacteristicWriteType = withResponse ? .withResponse : .withoutResponse
        active?.writeValue(data, for: c.cbCharacteristic, type: type)
        addLog(.write, "WRITE \(data.hexString) (\(withResponse ? "ack" : "no-ack")) · \(c.name)")
    }

    // MARK: - Internal helpers

    private func addLog(_ kind: LogEntry.Kind, _ text: String) {
        log.append(LogEntry(kind: kind, text: text))
        if log.count > 500 { log.removeFirst(log.count - 500) }
    }

    /// Republishing on every advertisement in firehose mode would thrash SwiftUI,
    /// so coalesce to ~5 Hz.
    private func scheduleRepublish() {
        guard republishTimer == nil else { return }
        republishTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            self?.republishTimer = nil
            self?.publishPeripherals()
        }
    }

    private func publishPeripherals() {
        peripherals = store.values
            .filter { $0.rssi >= minimumRSSI || $0.rssi == 0 }
            .sorted { $0.rssi > $1.rssi }
    }

    /// Rebuild the GATT snapshot from the live CBPeripheral object graph.
    private func rebuildServices() {
        guard let p = active else { services = []; return }
        services = (p.services ?? []).map { svc in
            let chars = (svc.characteristics ?? []).map { ch in
                GATTCharacteristic(
                    id: ObjectIdentifier(ch),
                    uuid: ch.uuid,
                    properties: ch.properties,
                    cbCharacteristic: ch,
                    value: ch.value,
                    isNotifying: ch.isNotifying,
                    descriptors: (ch.descriptors ?? []).map { d in
                        GATTDescriptor(
                            id: ObjectIdentifier(d),
                            uuid: d.uuid,
                            cbDescriptor: d,
                            value: Self.describeDescriptor(d.value)
                        )
                    }
                )
            }
            return GATTService(
                id: ObjectIdentifier(svc),
                uuid: svc.uuid,
                isPrimary: svc.isPrimary,
                cbService: svc,
                characteristics: chars
            )
        }
    }

    private static func describeDescriptor(_ value: Any?) -> String? {
        switch value {
        case let s as String:  return s
        case let n as NSNumber: return n.stringValue
        case let d as Data:    return d.hexString
        case .some(let other): return "\(other)"
        case .none:            return nil
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        // iOS relaunched us (possibly in the background) and is restoring our session.
        let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        for p in restored {
            p.delegate = self
            cbByID[p.identifier] = p
            if active == nil, p.state == .connected || p.state == .connecting {
                active = p
                connectedPeripheralID = p.identifier
            }
        }
        addLog(.info, "State restored · \(restored.count) peripheral(s)")
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
        switch central.state {
        case .poweredOn:  addLog(.info, "Bluetooth powered on")
        case .poweredOff: isScanning = false; addLog(.error, "Bluetooth powered off")
        case .unauthorized: addLog(.error, "Bluetooth permission denied — enable it in Settings")
        case .unsupported: addLog(.error, "BLE unsupported on this device")
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        cbByID[peripheral.identifier] = peripheral
        let parsed = AdvertisementDecoder.parse(advertisementData)
        let rssi = RSSI.intValue
        let now = Date()

        if var existing = store[peripheral.identifier] {
            existing.lastSeen = now
            existing.rssiHistory.append(rssi)
            if existing.rssiHistory.count > 60 { existing.rssiHistory.removeFirst() }
            existing.advertisement = parsed
            if let n = peripheral.name { existing.name = n }
            store[peripheral.identifier] = existing
        } else {
            let connectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false
            store[peripheral.identifier] = DiscoveredPeripheral(
                id: peripheral.identifier,
                name: peripheral.name ?? parsed.localName,
                rssiHistory: [rssi],
                firstSeen: now,
                lastSeen: now,
                advertisement: parsed,
                connectable: connectable
            )
        }
        scheduleRepublish()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = peripheral.state
        addLog(.info, "Connected. Discovering services…")
        peripheral.discoverServices(nil)   // discover everything
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
        addLog(.error, "Connect failed: \(error?.localizedDescription ?? "unknown")")
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
        if peripheral.identifier == connectedPeripheralID {
            addLog(.info, "Disconnected\(error.map { ": \($0.localizedDescription)" } ?? "")")
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { addLog(.error, "Service discovery error: \(error.localizedDescription)") }
        for svc in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: svc)
        }
        rebuildServices()
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { addLog(.error, "Characteristic discovery error: \(error.localizedDescription)") }
        for ch in service.characteristics ?? [] {
            peripheral.discoverDescriptors(for: ch)
        }
        rebuildServices()
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        rebuildServices()
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            addLog(.error, "Read/notify error · \(characteristic.uuid): \(error.localizedDescription)")
        } else if let v = characteristic.value {
            let name = AssignedNumbers.characteristicName(for: characteristic.uuid) ?? characteristic.uuid.uuidString
            addLog(characteristic.isNotifying ? .notify : .read,
                   "\(name) = \(v.hexString)  “\(v.asciiString)”")
        }
        rebuildServices()
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            addLog(.error, "Write error · \(characteristic.uuid): \(error.localizedDescription)")
        } else {
            addLog(.write, "Write acknowledged · \(characteristic.uuid)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            addLog(.error, "Notify state error · \(characteristic.uuid): \(error.localizedDescription)")
        }
        rebuildServices()
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        rebuildServices()
    }
}
