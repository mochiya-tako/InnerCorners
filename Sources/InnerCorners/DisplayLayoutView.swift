import SwiftUI

struct DisplayLayoutView: View {
    let displays: [DisplayDescriptor]
    let zoneSize: Double
    let barrierSegments: [BarrierPreviewSegment]
    let hoveredZoneID: String?
    let lastHitBarrierID: String?
    let selectedDisplayID: String?
    let selectedCorner: Corner
    let language: AppLanguage
    let cornerPolicy: (String, Corner) -> CornerBarrierPolicy
    let cornerBadge: (String, Corner) -> String
    let onSelectCorner: (String, Corner) -> Void

    private var bounds: CGRect {
        displays.map(\.frame).reduce(.null) { $0.union($1) }
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let padding: CGFloat = 14
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
                        let dRect = transformed(display.frame, union: union, scale: scale, offsetX: offsetX, offsetY: offsetY)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.08))
                            .stroke(Color.blue.opacity(0.55), lineWidth: 1.5)
                            .frame(width: dRect.width, height: dRect.height)
                            .position(x: dRect.midX, y: dRect.midY)

                        VStack(spacing: 2) {
                            Text(display.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text("#\(display.displayNumber) · \(Int(display.frame.width))×\(Int(display.frame.height))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .position(x: dRect.midX, y: dRect.midY)

                        // Interactive corner zones anchored strictly inside `dRect`
                        ForEach(Corner.allCases) { corner in
                            let zoneID = "\(display.id):\(corner.rawValue)"
                            let cRect = cornerRect(in: dRect, corner: corner, scale: scale)
                            let isSelected = (display.id == selectedDisplayID && corner == selectedCorner)
                            let isHovered = (zoneID == hoveredZoneID)
                            let policy = cornerPolicy(display.id, corner)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(zoneFillColor(policy: policy, isHovered: isHovered, isSelected: isSelected))
                                .stroke(
                                    isSelected ? Color.accentColor : (isHovered ? Color.orange : Color.teal.opacity(0.6)),
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                                .frame(width: cRect.width, height: cRect.height)
                                .position(x: cRect.midX, y: cRect.midY)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelectCorner(display.id, corner)
                                }
                                .help("\(display.name) · \(corner.title(language: language)): \(cornerBadge(display.id, corner))")
                        }
                    }

                    // Directional junction barriers anchored strictly along the inner edge of their owner display
                    ForEach(barrierSegments) { segment in
                        if let owner = displays.first(where: { $0.id == segment.displayPersistentID }) {
                            let dRect = transformed(owner.frame, union: union, scale: scale, offsetX: offsetX, offsetY: offsetY)
                            let bRect = barrierRect(in: dRect, segment: segment, scale: scale)
                            let isHit = (segment.id == lastHitBarrierID)

                            Capsule()
                                .fill(barrierColor(policy: segment.policy, isHit: isHit))
                                .frame(width: bRect.width, height: bRect.height)
                                .shadow(color: isHit ? .red.opacity(0.85) : .clear, radius: isHit ? 4 : 0)
                                .position(x: bRect.midX, y: bRect.midY)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
            .frame(height: 230)

            HStack(spacing: 14) {
                legendItem(color: .cyan, label: L10n.text(language, ja: "接合部の壁（有効）", en: "Barrier (Active)"))
                legendItem(color: .purple, label: L10n.text(language, ja: "ストッパー専用", en: "Stopper Only"))
                legendItem(color: .gray.opacity(0.45), label: L10n.text(language, ja: "壁なし（通過）", en: "No Barrier (Pass)"))
                legendItem(color: .orange, label: L10n.text(language, ja: "現在のポインタ／衝突", en: "Current Pointer / Hit"))
                Spacer()
                Text(L10n.text(language, ja: "💡 各コーナーをクリックして直接設定できます", en: "💡 Click any corner to configure it"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(L10n.text(language, ja: "ディスプレイ配置と接合部ソフトバリア", en: "Display layout and junction barriers"))
    }

    private func cornerRect(in dRect: CGRect, corner: Corner, scale: CGFloat) -> CGRect {
        let rawSize = CGFloat(zoneSize) * scale
        let w = min(max(18, rawSize), max(1, dRect.width * 0.42))
        let h = min(max(18, rawSize), max(1, dRect.height * 0.42))
        switch corner {
        case .topLeft:
            return CGRect(x: dRect.minX, y: dRect.minY, width: w, height: h)
        case .topRight:
            return CGRect(x: dRect.maxX - w, y: dRect.minY, width: w, height: h)
        case .bottomLeft:
            return CGRect(x: dRect.minX, y: dRect.maxY - h, width: w, height: h)
        case .bottomRight:
            return CGRect(x: dRect.maxX - w, y: dRect.maxY - h, width: w, height: h)
        }
    }

    private func barrierRect(in dRect: CGRect, segment: BarrierPreviewSegment, scale: CGFloat) -> CGRect {
        let thickness: CGFloat = 5
        switch segment.axis {
        case .vertical:
            let scaledSpan = segment.rect.height * scale
            let len = min(max(14, scaledSpan), max(1, dRect.height * 0.48))
            let x = (segment.corner == .topLeft || segment.corner == .bottomLeft)
                ? dRect.minX
                : (dRect.maxX - thickness)
            let y = (segment.corner == .topLeft || segment.corner == .topRight)
                ? dRect.minY
                : (dRect.maxY - len)
            return CGRect(x: x, y: y, width: thickness, height: len)
        case .horizontal:
            let scaledSpan = segment.rect.width * scale
            let len = min(max(14, scaledSpan), max(1, dRect.width * 0.48))
            let x = (segment.corner == .topLeft || segment.corner == .bottomLeft)
                ? dRect.minX
                : (dRect.maxX - len)
            let y = (segment.corner == .topLeft || segment.corner == .topRight)
                ? dRect.minY
                : (dRect.maxY - thickness)
            return CGRect(x: x, y: y, width: len, height: thickness)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func zoneFillColor(policy: CornerBarrierPolicy, isHovered: Bool, isSelected: Bool) -> Color {
        if isHovered {
            return Color.orange.opacity(0.82)
        }
        switch policy {
        case .enabled:
            return isSelected ? Color.accentColor.opacity(0.32) : Color.teal.opacity(0.28)
        case .stopperOnly:
            return isSelected ? Color.purple.opacity(0.38) : Color.purple.opacity(0.24)
        case .disabled:
            return Color.gray.opacity(0.14)
        }
    }

    private func barrierColor(policy: CornerBarrierPolicy, isHit: Bool) -> Color {
        if isHit {
            return Color.red
        }
        switch policy {
        case .enabled:
            return Color.cyan
        case .stopperOnly:
            return Color.purple
        case .disabled:
            return Color.gray.opacity(0.35)
        }
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
