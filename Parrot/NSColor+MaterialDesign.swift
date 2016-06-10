import Cocoa

// NSColor extensions that are useful for an application like this.
public extension NSColor {
	
	// Parse an NSColor from a hex string.
	// from: https://github.com/thii/SwiftHEXColors
	public convenience init(hex: String, alpha: Float = 1.0) {
		var hex = hex
		
		// Strip leading # prefix from hex digits.
		if hex.hasPrefix("#") {
			hex = hex.substring(from: hex.index(hex.startIndex, offsetBy: 1))
		}
		
		// Ensure it's actually a color string, otherwise bail.
		if hex.range(of: "(^[0-9A-Fa-f]{6}$)|(^[0-9A-Fa-f]{3}$)", options: .regularExpressionSearch) == nil {
			self.init(calibratedRed: 0, green: 0, blue: 0, alpha: 1)
			return
		}
		
		// If it's a short-form (3 character) color, expand it.
		if hex.characters.count == 3 {
			let r = hex.substring(to: hex.index(hex.startIndex, offsetBy: 1))
			let g = hex.substring(with: hex.index(hex.startIndex, offsetBy: 1)..<hex.index(hex.startIndex, offsetBy: 2))
			let b = hex.substring(from: hex.index(hex.startIndex, offsetBy: 2))
			hex = r + r + g + g + b + b
		}
		
		// Split the color components out.
		let rh = hex.substring(to: hex.index(hex.startIndex, offsetBy: 2))
		let gh = hex.substring(with: hex.index(hex.startIndex, offsetBy: 2)..<hex.index(hex.startIndex, offsetBy: 4))
		let bh = hex.substring(with: hex.index(hex.startIndex, offsetBy: 4)..<hex.index(hex.startIndex, offsetBy: 6))
		
		// Scan the color components into integers.
		var r: UInt32 = 0, g: UInt32 = 0, b: UInt32 = 0
		NSScanner(string: rh).scanHexInt32(&r)
		NSScanner(string: gh).scanHexInt32(&g)
		NSScanner(string: bh).scanHexInt32(&b)
		
		// Finally initialize with the calibrated color components.
		self.init(calibratedRed: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0,
				  blue: CGFloat(b) / 255.0, alpha: CGFloat(alpha))
	}
	
	// 
	// Material Design colors follow:
	//
	
	public class func materialRed() -> NSColor {
		return NSColor(hex: "#F44336")
	}
	
	public class func materialPink() -> NSColor {
		return NSColor(hex: "#E91E63")
	}
	
	public class func materialPurple() -> NSColor {
		return NSColor(hex: "#9C27B0")
	}
	
	public class func materialDeepPurple() -> NSColor {
		return NSColor(hex: "#673AB7")
	}
	
	public class func materialIndigo() -> NSColor {
		return NSColor(hex: "#3F51B5")
	}
	
	public class func materialBlue() -> NSColor {
		return NSColor(hex: "#2196F3")
	}
	
	public class func materialLightBlue() -> NSColor {
		return NSColor(hex: "#03A9F4")
	}
	
	public class func materialCyan() -> NSColor {
		return NSColor(hex: "#00BCD4")
	}
	
	public class func materialTeal() -> NSColor {
		return NSColor(hex: "#009688")
	}
	
	public class func materialGreen() -> NSColor {
		return NSColor(hex: "#4CAF50")
	}
	
	public class func materialLightGreen() -> NSColor {
		return NSColor(hex: "#8BC34A")
	}
	
	public class func materialLime() -> NSColor {
		return NSColor(hex: "#CDDC39")
	}
	
	public class func materialYellow() -> NSColor {
		return NSColor(hex: "#FFEB3B")
	}
	
	public class func materialAmber() -> NSColor {
		return NSColor(hex: "#FFC107")
	}
	
	public class func materialOrange() -> NSColor {
		return NSColor(hex: "#FF9800")
	}
	
	public class func materialDeepOrange() -> NSColor {
		return NSColor(hex: "#FF5722")
	}
	
	public class func materialBrown() -> NSColor {
		return NSColor(hex: "#795548")
	}
	
	public class func materialGrey() -> NSColor {
		return NSColor(hex: "#9E9E9E")
	}
	
	public class func materialBlueGrey() -> NSColor {
		return NSColor(hex: "#607D8B")
	}
}
