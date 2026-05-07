import UIKit

enum Typography {
    /// Register all Poppins files under `Fonts/` via Info.plist (`UIAppFonts`).
    static func poppins(_ weight: PoppinsWeight, size: CGFloat) -> UIFont {
        UIFont(name: weight.rawValue, size: size)
            ?? .systemFont(ofSize: size, weight: weight.systemFallback)
    }

    static func poppinsItalic(_ weight: PoppinsItalicWeight, size: CGFloat) -> UIFont {
        UIFont(name: weight.rawValue, size: size)
            ?? .italicSystemFont(ofSize: size)
    }

    enum PoppinsItalicWeight: String {
        case thinItalic = "Poppins-ThinItalic"
        case extraLightItalic = "Poppins-ExtraLightItalic"
        case lightItalic = "Poppins-LightItalic"
        case italic = "Poppins-Italic"
        case mediumItalic = "Poppins-MediumItalic"
        case semiBoldItalic = "Poppins-SemiBoldItalic"
        case boldItalic = "Poppins-BoldItalic"
        case extraBoldItalic = "Poppins-ExtraBoldItalic"
        case blackItalic = "Poppins-BlackItalic"
    }

    enum PoppinsWeight: String {
        case thin = "Poppins-Thin"
        case extraLight = "Poppins-ExtraLight"
        case light = "Poppins-Light"
        case regular = "Poppins-Regular"
        case medium = "Poppins-Medium"
        case semiBold = "Poppins-SemiBold"
        case bold = "Poppins-Bold"
        case extraBold = "Poppins-ExtraBold"
        case black = "Poppins-Black"

        var systemFallback: UIFont.Weight {
            switch self {
            case .thin: return .thin
            case .extraLight: return .ultraLight
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semiBold: return .semibold
            case .bold: return .bold
            case .extraBold: return .heavy
            case .black: return .black
            }
        }
    }
}
