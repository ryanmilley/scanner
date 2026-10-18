import SwiftUI

struct LogView: View {
    @EnvironmentObject var bt: BluetoothManager

    var body: some View {
        List {
            ForEach(bt.log.reversed()) { entry in
                LogRow(entry: entry)
            }
        }
        .navigationTitle("Activity Log")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if bt.log.isEmpty {
                ContentUnavailableView("No activity yet",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Scan, connect, and probe to see events here."))
            }
        }
    }
}

struct LogRow: View {
    let entry: LogEntry

    private static let formatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.text).font(.caption.monospaced())
                Text(Self.formatter.string(from: entry.time))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var icon: String {
        switch entry.kind {
        case .info:   return "info.circle"
        case .read:   return "arrow.down.circle"
        case .write:  return "arrow.up.circle"
        case .notify: return "bell"
        case .error:  return "exclamationmark.triangle"
        }
    }
    private var color: Color {
        switch entry.kind {
        case .info:   return .secondary
        case .read:   return .blue
        case .write:  return .orange
        case .notify: return .purple
        case .error:  return .red
        }
    }
}
