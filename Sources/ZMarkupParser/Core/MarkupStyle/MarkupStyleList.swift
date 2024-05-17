//
//  MarkupStyleList.swift
//  
//
//  Created by https://zhgchg.li on 2023/3/9.
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct MarkupStyleList {
    let type: MarkupStyleType
    let format: String
    let startingItemNumber: Int
    let nsTextList: NSTextList
    
    public init(type: MarkupStyleType, format: String, startingItemNumber: Int) {
        self.type = type
        self.format = format
        self.startingItemNumber = startingItemNumber
        let nsTextList = NSTextList(markerFormat: type.markerFormat(), options: 0)
        nsTextList.startingItemNumber = startingItemNumber
        self.nsTextList = nsTextList
    }
    
    func marker(forItemNumber itemNumber: Int) -> String {
        return "   \(marker(forItemNumber: itemNumber, format: format))   "
    }
    
    private func marker(forItemNumber itemNumber: Int, format: String) -> String {
        return String(format: format, nsTextList.marker(forItemNumber: itemNumber))
    }
    
    public enum MarkupStyleType {
        case octal
        case lowercaseAlpha
        case decimal
        case lowercaseHexadecimal
        case lowercaseLatin
        case lowercaseRoman
        case uppercaseAlpha
        case uppercaseLatin
        case uppercaseRoman
        case uppercaseHexadecimal
        case hyphen
        case check
        case circle
        case disc
        case diamond
        case box
        case square
        
        func isOrder() -> Bool {
            switch self {
            case .octal,.lowercaseAlpha,.decimal,.lowercaseHexadecimal,.lowercaseLatin,.lowercaseRoman,.uppercaseAlpha,.uppercaseLatin,.uppercaseRoman,.uppercaseHexadecimal:
                return true
            case .hyphen, .check, .circle, .disc, .diamond, .box, .square:
                return false
            }
        }
        
        fileprivate func markerFormat() -> NSTextList.MarkerFormat {
            switch self {
            case .octal:
                return .octal
            case .lowercaseAlpha:
                return .lowercaseAlpha
            case .decimal:
                return .decimal
            case .lowercaseHexadecimal:
                return .lowercaseHexadecimal
            case .lowercaseLatin:
                return .lowercaseLatin
            case .lowercaseRoman:
                return .lowercaseRoman
            case .uppercaseAlpha:
                return .uppercaseAlpha
            case .uppercaseLatin:
                return .uppercaseLatin
            case .uppercaseRoman:
                return .uppercaseRoman
            case .uppercaseHexadecimal:
                return .uppercaseHexadecimal
            case .hyphen:
                return .hyphen
            case .check:
                return .check
            case .circle:
                return .circle
            case .disc:
                return .disc
            case .diamond:
                return .diamond
            case .box:
                return .box
            case .square:
                return .square
            }
        }
    }

}
