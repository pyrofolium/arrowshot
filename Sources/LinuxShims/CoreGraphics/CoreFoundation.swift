import Foundation

// The CoreFoundation types Apple's CoreGraphics and ImageIO take, as their Swift counterparts, so
// code written `url as CFURL` or `[key: value] as CFDictionary` builds unchanged on Linux.
public typealias CFString = String
public typealias CFURL = URL
public typealias CFDictionary = [String: Any]
