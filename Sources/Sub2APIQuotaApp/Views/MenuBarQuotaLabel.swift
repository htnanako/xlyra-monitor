import AppKit
import SwiftUI
import Sub2APIQuotaCore

struct MenuBarQuotaLabel: View {
    @ObservedObject var state: AppState
    @ObservedObject var preferences: AppPreferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let model = StatusViewModel(
            status: state.status,
            snapshot: state.quotaSnapshot,
            lastError: state.lastError,
            lastRequestDuration: state.lastRequestDuration
        )
        let palette = MenuBarPalette(mode: preferences.themeMode, systemColorScheme: colorScheme)

        Image(nsImage: MenuBarQuotaImageRenderer.image(
            for: model,
            showsNumbers: preferences.showsMenuBarNumbers,
            palette: palette
        ))
            .accessibilityLabel(model.subtitle)
    }
}

enum MenuBarQuotaImageRenderer {
    static func image(for model: StatusViewModel, showsNumbers: Bool, palette: MenuBarPalette) -> NSImage {
        if model.snapshot?.poolSummary != nil {
            return accountPoolImage(for: model, showsNumbers: showsNumbers, palette: palette)
        }

        return fallbackImage(for: model, palette: palette)
    }

    private static func accountPoolImage(
        for model: StatusViewModel,
        showsNumbers: Bool,
        palette: MenuBarPalette
    ) -> NSImage {
        let valueFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        let barWidth: CGFloat = 30
        let markRect = CGRect(x: 0, y: 2.5, width: 17, height: 17)
        let labelX = markRect.maxX + 3
        let barX = labelX + 17 + 3
        let valueX = barX + barWidth + 3
        let fiveHourValue = showsNumbers ? model.fiveHourRemainingShortText : nil
        let sevenDayValue = showsNumbers ? model.sevenDayRemainingShortText : nil
        let valueWidth = max(
            measuredWidth(fiveHourValue, font: valueFont),
            measuredWidth(sevenDayValue, font: valueFont)
        )
        let imageWidth = showsNumbers ? valueX + valueWidth : barX + barWidth
        let size = NSSize(width: ceil(imageWidth), height: 22)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        drawStatusMark(
            colorName: model.colorName,
            centerText: model.availableAccountCountText,
            in: markRect,
            palette: palette
        )
        drawRow(
            label: "5h",
            value: fiveHourValue,
            progress: model.fiveHourUsedFraction,
            tint: color(for: model.fiveHourRiskColorName),
            palette: palette,
            labelX: labelX,
            barX: barX,
            barWidth: barWidth,
            valueX: valueX,
            valueWidth: valueWidth,
            valueFont: valueFont,
            y: 12
        )
        drawRow(
            label: "7d",
            value: sevenDayValue,
            progress: model.sevenDayUsedFraction,
            tint: color(for: model.sevenDayRiskColorName),
            palette: palette,
            labelX: labelX,
            barX: barX,
            barWidth: barWidth,
            valueX: valueX,
            valueWidth: valueWidth,
            valueFont: valueFont,
            y: 2
        )

        return image
    }

    private static func fallbackImage(for model: StatusViewModel, palette: MenuBarPalette) -> NSImage {
        let size = NSSize(width: 86, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        drawStatusMark(colorName: model.colorName, centerText: nil, in: CGRect(x: 0, y: 2, width: 14, height: 14), palette: palette)
        drawText(
            Sub2APIQuotaAppMetadata.menuBarTitle,
            rect: CGRect(x: 18, y: 1, width: 68, height: 16),
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: palette.text,
            alignment: .left
        )

        return image
    }

    private static func drawRow(
        label: String,
        value: String?,
        progress: Double,
        tint: NSColor,
        palette: MenuBarPalette,
        labelX: CGFloat,
        barX: CGFloat,
        barWidth: CGFloat,
        valueX: CGFloat,
        valueWidth: CGFloat,
        valueFont: NSFont,
        y: CGFloat
    ) {
        drawText(
            label,
            rect: CGRect(x: labelX, y: y - 1.5, width: 17, height: 11),
            font: .monospacedSystemFont(ofSize: 9, weight: .semibold),
            color: palette.text,
            alignment: .left
        )

        let barRect = CGRect(x: barX, y: y + 2, width: barWidth, height: 4)
        let backgroundPath = NSBezierPath(roundedRect: barRect, xRadius: 2, yRadius: 2)
        palette.track.setFill()
        backgroundPath.fill()

        let filledWidth = max(0, min(1, progress)) * barRect.width
        if filledWidth > 0 {
            let filledRect = CGRect(x: barRect.minX, y: barRect.minY, width: filledWidth, height: barRect.height)
            let filledPath = NSBezierPath(roundedRect: filledRect, xRadius: 2, yRadius: 2)
            tint.setFill()
            filledPath.fill()
        }

        if let value {
            drawText(
                value,
                rect: CGRect(x: valueX, y: y - 1.5, width: valueWidth, height: 11),
                font: valueFont,
                color: palette.text,
                alignment: .left
            )
        }
    }

    private static func measuredWidth(_ text: String?, font: NSFont) -> CGFloat {
        guard let text, text.isEmpty == false else {
            return 0
        }

        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil(NSString(string: text).size(withAttributes: attributes).width)
    }

    private static func drawStatusMark(colorName: String, centerText: String?, in rect: CGRect, palette: MenuBarPalette) {
        let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 1.1, dy: 1.1))
        color(for: colorName).setStroke()
        ring.lineWidth = 1.8
        ring.stroke()

        guard let centerText, centerText.isEmpty == false else {
            color(for: colorName).setFill()
            NSBezierPath(ovalIn: CGRect(x: rect.midX - 1.8, y: rect.midY - 1.8, width: 3.6, height: 3.6)).fill()
            return
        }

        let fontSize: CGFloat = centerText.count >= 3 ? 7 : 9.5
        drawText(
            centerText,
            rect: CGRect(x: rect.minX, y: rect.midY - 6, width: rect.width, height: 12),
            font: .monospacedSystemFont(ofSize: fontSize, weight: .bold),
            color: palette.text,
            alignment: .center
        )
    }

    private static func drawText(
        _ text: String,
        rect: CGRect,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byClipping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        NSString(string: text).draw(in: rect, withAttributes: attributes)
    }

    static func color(for colorName: String) -> NSColor {
        switch colorName {
        case "green":
            return .systemGreen
        case "yellow":
            return .systemYellow
        case "orange":
            return .systemOrange
        case "red":
            return .systemRed
        default:
            return .systemGray
        }
    }
}

struct MenuBarPalette: Equatable {
    let text: NSColor
    let track: NSColor

    init(mode: AppThemeMode, systemColorScheme: ColorScheme) {
        if mode.resolvesToDark(systemColorScheme: systemColorScheme) {
            text = .white
            track = NSColor.white.withAlphaComponent(0.24)
        } else {
            text = NSColor.black.withAlphaComponent(0.82)
            track = NSColor.black.withAlphaComponent(0.18)
        }
    }

    static func == (lhs: MenuBarPalette, rhs: MenuBarPalette) -> Bool {
        lhs.text == rhs.text && lhs.track == rhs.track
    }
}
