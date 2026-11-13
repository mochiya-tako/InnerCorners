import SwiftUI

struct DisplayLayoutView: View {
    let displays: [DisplayDescriptor]
    let zoneSize: Double
    let hoveredZoneID: String?
    let language: AppLanguage

    private var bounds: CGRect {
        displays.map(\.frame).reduce(.null) { $0.union($1) }
    }

    var body: some View {
        GeometryReader { proxy in
            let padding: CGFloat = 12
            let availableWidth = max(1, proxy.size.width - padding * 2)
            let availableHeight = max(1, proxy.size.height - padding * 2)
            let union = bounds
            let scale = union.isNull ? 1 : min(availableWidth / union.width, availableHeight / union.height)
            let drawingWidth = union.width * scale
            let drawingHeight = union.height * scale
            let offsetX = (proxy.size.width - drawingWidth) / 2
            let offsetY = (proxy.size.height - drawingHeight) / 2

            ZStack(alignment: .topLeading) {
                ForEach(displays) { display in
                    let rect = transformed(display.frame, union: union, scale: scale, offsetX: offsetX, offsetY: offsetY)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.blue.opacity(0.10))
                        .stroke(.blue.opacity(0.7), lineWidth: 1)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                    Text(display.name)
                        .font(.caption2)
                        .lineLimit(1)
                        .position(x: rect.midX, y: rect.midY)
                }

                ForEach(HotZoneGeometry.zones(for: displays, size: zoneSize)) { zone in
                    let rect = transformed(zone.rect, union: union, scale: scale, offsetX: offsetX, offsetY: offsetY)
                    Rectangle()
                        .fill(zone.id == hoveredZoneID ? Color.orange.opacity(0.85) : Color.teal.opacity(0.40))
                        .frame(width: max(3, rect.width), height: max(3, rect.height))
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .frame(height: 220)
        .accessibilityLabel(L10n.text(language, ja: "ディスプレイ配置とホットコーナー反応領域", en: "Display layout and Hot Corner activation zones"))
    }

    private func transformed(
        _ rect: CGRect,
        union: CGRect,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> CGRect {
        CGRect(
            x: offsetX + (rect.minX - union.minX) * scale,
            y: offsetY + (union.maxY - rect.maxY) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }
}
