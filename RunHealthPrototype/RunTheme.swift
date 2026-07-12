import MapKit
import SwiftUI
import UIKit

enum MapTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "selectedMapTheme"

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .system:
            return "시스템 설정 따르기"
        case .light:
            return "밝은 지도"
        case .dark:
            return "어두운 지도"
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .system:
            return .standard
        case .light:
            return .standard
        case .dark:
            return .imagery(elevation: .flat)
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system:
            return .unspecified
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum RunTheme {
    static let appName = "RunLog"
    static let tagline = "Health 기반 러닝 기록"

    static let backgroundPrimary = Color(red: 0.96, green: 0.97, blue: 0.96)
    static let cardBackground = Color.white
    static let subtleBackground = Color(red: 0.93, green: 0.95, blue: 0.94)
    static let textPrimary = Color(red: 0.08, green: 0.10, blue: 0.11)
    static let textSecondary = Color(red: 0.36, green: 0.40, blue: 0.43)
    static let textTertiary = Color(red: 0.53, green: 0.57, blue: 0.60)
    static let accent = Color(red: 0.05, green: 0.48, blue: 0.42)
    static let borderSubtle = Color.black.opacity(0.06)
    static let accentSoft = Color(red: 0.86, green: 0.95, blue: 0.93)
    static let routeAccent = Color(red: 0.24, green: 0.88, blue: 0.20)
    static let paceFast = Color(red: 0.19, green: 0.68, blue: 0.35)
    static let paceNormal = Color(red: 0.84, green: 0.66, blue: 0.16)
    static let paceSlow = Color(red: 0.79, green: 0.29, blue: 0.25)
    static let errorText = Color(red: 0.72, green: 0.18, blue: 0.18)
    static let errorBackground = Color(red: 0.98, green: 0.92, blue: 0.92)
    static let onAccentText = Color.white
    static let mapMarkerStroke = Color.white
    static let overlayBackground = Color.black.opacity(0.62)
    static let overlayControlBackground = Color.white.opacity(0.16)
    static let overlayTextPrimary = Color.white
    static let overlayTextSecondary = Color.white.opacity(0.78)

    static let metricLarge = Font.system(size: 38, weight: .bold, design: .rounded)
    static let title = Font.system(size: 19, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 15, weight: .medium, design: .rounded)
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)

    static let cardRadius: CGFloat = 18
    static let compactSpacing: CGFloat = 8
    static let contentSpacing: CGFloat = 14
    static let cardInnerSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 20
    static let pagePadding: CGFloat = 20
    static let smoothAnimation = Animation.easeInOut(duration: 0.22)

    static let primaryText = textPrimary
    static let secondaryText = textSecondary
    static let tertiaryText = textTertiary
    static let screenBackground = backgroundPrimary
    static let divider = borderSubtle
    static let accentText = accent

    static let ink = primaryText
    static let secondaryInk = secondaryText
    static let background = screenBackground
    static let card = cardBackground
    static let insetCard = subtleBackground
}

struct RunCardStyle: ViewModifier {
    var padding: CGFloat = 18
    var background: Color = RunTheme.cardBackground
    var shadowOpacity: Double = 0.07

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: RunTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: RunTheme.cardRadius, style: .continuous)
                    .stroke(RunTheme.borderSubtle, lineWidth: 1)
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: 16, x: 0, y: 8)
    }
}

extension View {
    func runCard(
        padding: CGFloat = 18,
        background: Color = RunTheme.cardBackground,
        shadowOpacity: Double = 0.07
    ) -> some View {
        modifier(
            RunCardStyle(
                padding: padding,
                background: background,
                shadowOpacity: shadowOpacity
            )
        )
    }

    func runMapTheme(_ mapTheme: MapTheme) -> some View {
        modifier(RunMapThemeModifier(mapTheme: mapTheme))
    }
}

private struct RunMapThemeModifier: ViewModifier {
    let mapTheme: MapTheme

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(mapTheme.preferredColorScheme)
    }
}

struct RunSectionTitle: View {
    let title: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(RunTheme.title)
                .foregroundStyle(RunTheme.textPrimary)

            if let caption {
                Text(caption)
                    .font(RunTheme.caption)
                    .foregroundStyle(RunTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RunHeroCard<BottomContent: View>: View {
    let title: String
    let systemImage: String
    let value: String
    let subtitle: String?
    @ViewBuilder let bottomContent: () -> BottomContent

    init(
        title: String,
        systemImage: String,
        value: String,
        subtitle: String? = nil,
        @ViewBuilder bottomContent: @escaping () -> BottomContent = { EmptyView() }
    ) {
        self.title = title
        self.systemImage = systemImage
        self.value = value
        self.subtitle = subtitle
        self.bottomContent = bottomContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RunTheme.contentSpacing) {
            Label(title, systemImage: systemImage)
                .font(RunTheme.caption)
                .foregroundStyle(RunTheme.textSecondary)

            Text(value)
                .font(RunTheme.metricLarge)
                .foregroundStyle(RunTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let subtitle {
                Text(subtitle)
                    .font(RunTheme.body)
                    .foregroundStyle(RunTheme.textSecondary)
            }

            bottomContent()
        }
        .runCard()
    }
}

struct RunMetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: RunTheme.compactSpacing) {
            Label(title, systemImage: systemImage)
                .font(RunTheme.caption)
                .foregroundStyle(RunTheme.textSecondary)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(RunTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .runCard(padding: 16, background: RunTheme.cardBackground, shadowOpacity: 0.05)
    }
}

struct RunActionRowCard: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    init(title: String, subtitle: String? = nil, systemImage: String) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(RunTheme.accentSoft)
                    .frame(width: 38, height: 38)

                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RunTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RunTheme.body)
                    .foregroundStyle(RunTheme.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(RunTheme.caption)
                        .foregroundStyle(RunTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RunTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .runCard(padding: 16, background: RunTheme.cardBackground, shadowOpacity: 0.05)
    }
}

enum RunBadgeTone {
    case accent
    case neutral
    case error

    var foregroundColor: Color {
        switch self {
        case .accent:
            return RunTheme.accent
        case .neutral:
            return RunTheme.textSecondary
        case .error:
            return RunTheme.errorText
        }
    }

    var backgroundColor: Color {
        switch self {
        case .accent:
            return RunTheme.accentSoft
        case .neutral:
            return RunTheme.subtleBackground
        case .error:
            return RunTheme.errorBackground
        }
    }
}

struct RunBadge: View {
    let text: String
    var systemImage: String? = nil
    var tone: RunBadgeTone = .neutral

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
            }

            Text(text)
        }
        .font(RunTheme.caption)
        .foregroundStyle(tone.foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tone.backgroundColor)
        .clipShape(Capsule())
    }
}
