import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit

// MARK: - UIColor Extensions for System Colors
extension UIColor {
    // Ensure all system colors are available
    @available(iOS 13.0, *)
    static var compatibleSystemBackground: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.systemBackground
        } else {
            return UIColor.white
        }
    }
    
    @available(iOS 13.0, *)
    static var compatibleSystemGray4: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.systemGray4
        } else {
            return UIColor.lightGray
        }
    }
    
    @available(iOS 13.0, *)
    static var compatibleSystemBlue: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.systemBlue
        } else {
            return UIColor.blue
        }
    }
    
    @available(iOS 13.0, *)
    static var compatibleSystemYellow: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.systemYellow
        } else {
            return UIColor.yellow
        }
    }
    
    @available(iOS 13.0, *)
    static var compatibleSystemRed: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.systemRed
        } else {
            return UIColor.red
        }
    }
    
    @available(iOS 13.0, *)
    static var compatibleSeparator: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.separator
        } else {
            return UIColor.lightGray
        }
    }
}

// MARK: - Color Extensions for SwiftUI compatibility
extension Color {
    // System Colors for compatibility
    static let systemBackground = Color(UIColor.compatibleSystemBackground)
    static let systemGray4 = Color(UIColor.compatibleSystemGray4)
    static let systemBlue = Color(UIColor.compatibleSystemBlue)
    static let systemYellow = Color(UIColor.compatibleSystemYellow)
    static let systemRed = Color(UIColor.compatibleSystemRed)
    static let separator = Color(UIColor.compatibleSeparator)
    
    // UIColor conversion
    var uiColor: UIColor {
        return UIColor(self)
    }
}

#else
// For non-UIKit platforms, define basic colors
extension Color {
    static let systemBackground = Color.white
    static let systemGray4 = Color.gray
    static let systemBlue = Color.blue
    static let systemYellow = Color.yellow
    static let systemRed = Color.red
    static let separator = Color.gray
}
#endif 
