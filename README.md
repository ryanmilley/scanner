# Probe — a BLE explorer for iOS, built without a Mac

Probe is a Bluetooth Low Energy scanner, advertisement decoder, and GATT
read/write/notify playground for iPhone. It's built entirely in CI (GitHub
Actions runs the Mac) and installed by sideloading, so you never need a Mac of
your own — only a way to sideload onto your phone.

## What it does

- **Wildcard live scanner** — scans with no service filter and `allowDuplicates`
  on, so you see every advertising BLE device around you, sorted by signal.
- **Advertisement decoder** — service UUIDs, service data, Tx power, and
  manufacturer data parsed by Bluetooth SIG company ID, including an Apple
  `0x004C` Continuity / Find My / AirPods / iBeacon parser.
- **GATT explorer** — connect, walk services → characteristics → descriptors,
  with standard UUIDs named.
- **Read / write / notify console** — read values, subscribe to notifications,
  and write raw hex or text to characteristics. This is the "see what happens"
  surface.
- **Background state restoration** — registers a `CBCentralManager` restore
  identifier so iOS can relaunch the app when a known peripheral reappears.

## What an iPhone genuinely can't do (and why)

These are enforced by the OS sandbox, not by App Store review, so **sideloading
does not unlock them** — only a jailbroken device or an external radio would:

- **No classic Bluetooth.** BLE only. Most legacy audio devices are invisible.
- **No hardware MAC addresses.** iOS gives each peripheral a per-app random
  UUID. Devices that rotate their address will appear as many different devices.
- **No raw packet / PHY sniffing.** You get advertisements and the GATT layer,
  never the radio. For that, pair an nRF52840 + Wireshark or an ESP32 later.

Everything Probe does is 100% public Core Bluetooth — no private entitlements.

## Building (GitHub Actions does the Mac work)

There is no `.xcodeproj` in the repo. [XcodeGen](https://github.com/yonaskolb/XcodeGen)
generates it from `project.yml` in CI, which keeps the project diff-friendly.

Every push to `main` (or a manual **Run workflow**) triggers
`.github/workflows/build.yml`, which:

1. installs XcodeGen and generates the project,
2. archives the app **unsigned**, and
3. packages and uploads an **unsigned `.ipa`** as a build artifact.

Download it from the run's **Artifacts** section (`BLEProbe-unsigned-ipa`).

## Installing (sideloading)

The IPA is unsigned on purpose — your sideload tool signs it with *your* Apple
ID at install time, so no certificates or credentials ever touch CI. Pick
whichever matches what you've got:

| Tool | Needs a computer? | Notes |
|------|-------------------|-------|
| **SideStore** | No (after one-time pairing) | On-device re-signing + background refresh. Best for the background-scanning features. |
| **AltStore** | Yes — Windows or Mac running AltServer | Mature; auto-refreshes over Wi-Fi while the computer is on. |
| **Sideloadly** | Yes — Windows or Mac, USB for install | Simple one-shot installs. |
| **ESign / Feather** | No | On-device signing with a free Apple ID cert. |

**Free Apple ID:** apps expire after 7 days and you're limited to 3 sideloaded
apps — you re-install when it lapses. **Paid ($99/yr):** 1-year signing and
cleaner background entitlements, which matters for the background-scan feature.
Start free; upgrade when the reinstall dance gets old.

After installing, launch Probe and allow the Bluetooth permission prompt.

## Changing the bundle ID / name

Edit `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` and `CFBundleDisplayName` in
`BLEProbe/Info.plist`. (Most sideload tools rewrite the bundle ID on install
anyway, so this is optional.)

## Project layout

```
project.yml                     XcodeGen project definition
BLEProbe/
  App/BLEProbeApp.swift         @main entry; instantiates the manager at launch
  Core/
    Models.swift                peripheral / GATT / log models + formatting
    BluetoothManager.swift      CBCentralManager: scan, connect, GATT, restoration
  Decode/
    AdvertisementDecoder.swift  raw adv dict → typed advertisement
    CompanyIdentifiers.swift    Bluetooth SIG company ID table
    AppleContinuityDecoder.swift Apple 0x004C TLV parser
    AssignedNumbers.swift       GATT service/characteristic/descriptor names
  Views/
    ScannerView.swift           live list sorted by RSSI
    PeripheralDetailView.swift  advertisement breakdown + GATT tree
    CharacteristicView.swift    read / write / notify console
    LogView.swift               activity log
.github/workflows/build.yml     unsigned-IPA CI pipeline
```

## A note on the write/fuzz features

Writing arbitrary values to characteristics can misconfigure or brick a device,
and a few BLE products are safety-relevant. Keep the write and notify
experiments to hardware you own.
