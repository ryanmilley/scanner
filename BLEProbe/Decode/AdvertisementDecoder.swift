import Foundation
import CoreBluetooth

/// Turns Core Bluetooth's raw advertisement dictionary into a typed, UI-friendly
/// `ParsedAdvertisement`. The dictionary keys are the `CBAdvertisementData*`
/// constants; values are loosely typed, so each is unwrapped defensively.
enum AdvertisementDecoder {

    static func parse(_ data: [String: Any]) -> ParsedAdvertisement {
        var adv = ParsedAdvertisement()

        adv.localName = data[CBAdvertisementDataLocalNameKey] as? String

        if let uuids = data[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            adv.serviceUUIDs = uuids
        }
        if let uuids = data[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] {
            adv.overflowServiceUUIDs = uuids
        }
        if let uuids = data[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID] {
            adv.solicitedServiceUUIDs = uuids
        }
        if let sd = data[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            adv.serviceData = sd
        }
        adv.manufacturerData = data[CBAdvertisementDataManufacturerDataKey] as? Data
        adv.txPowerLevel = (data[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue

        return adv
    }
}
