//
//  MarkupNSAttributedStringVisitor.swift
//  
//
//  Created by https://zhgchg.li on 2023/2/12.
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct MarkupNSAttributedStringVisitor: MarkupVisitor {
    
    typealias Result = NSAttributedString
    
    let components: [MarkupStyleComponent]
    let rootStyle: MarkupStyle?
    
    static let breakLineSymbol = "\n"
    
    func visit(_ markup: RootMarkup) -> Result {
        return reduceBreaklineInResultNSAttributedString(collectAttributedString(markup))
    }
    
    func visit(_ markup: BreakLineMarkup) -> Result {
        return makeString(in: markup, string: Self.breakLineSymbol, attributes: [.breaklinePlaceholder: NSAttributedString.Key.BreaklinePlaceholder.breaklineTag])
    }
    
    func visit(_ markup: RawStringMarkup) -> Result {
        return applyMarkupStyle(markup.attributedString, with: collectMarkupStyle(markup))
    }
    
    func visit(_ markup: ExtendMarkup) -> Result {
        return collectAttributedString(markup)
    }
        
    func visit(_ markup: BoldMarkup) -> Result {
        return collectAttributedString(markup)
    }
    
    func visit(_ markup: HorizontalLineMarkup) -> Result {
        let attributedString = collectAttributedString(markup)
        let thisAttributedString = NSMutableAttributedString(attributedString: makeString(in: markup, string: String(repeating: "-", count: markup.dashLength)))
        thisAttributedString.markPrefixTagBoundaryBreakline()
        thisAttributedString.markSuffixTagBoundaryBreakline()
        
        attributedString.append(thisAttributedString)
        return attributedString
    }
    
    func visit(_ markup: InlineMarkup) -> Result {
        return collectAttributedString(markup)
    }
    
    func visit(_ markup: ColorMarkup) -> Result {
        return collectAttributedString(markup)
    }
    
    func visit(_ markup: ItalicMarkup) -> Result {
        return collectAttributedString(markup)
    }
    
    func visit(_ markup: LinkMarkup) -> Result {
        return collectAttributedString(markup)
    }
    
    func visit(_ markup: ListItemMarkup) -> Result {
        guard let parentMarkup = markup.parentMarkup as? ListMarkup else {
            return collectAttributedString(markup)
        }
        
        let baseAttributedString = collectAttributedString(markup)
        let attributedString = NSMutableAttributedString(attributedString: reduceBreaklineInResultNSAttributedString(baseAttributedString))
        
        let markupStyle = collectMarkupStyle(markup) ?? .default
        let listItemParagraphStyle = markupStyle.paragraphStyle.getParagraphStyle() ?? .default
        
        // Handle line breaks inside the list item same identation on the new line as the list item
        let tabStopCount = listItemParagraphStyle.tabStops.count
        attributedString.mutableString.replaceOccurrences(
            of: "\n",
            with: "\n\(String(repeating: "\t", count: tabStopCount))",
            range: NSRange(location: 0, length: attributedString.string.utf16.count)
        )
        
        let siblingListItems = markup.parentMarkup?.childMarkups.filter({ $0 is ListItemMarkup }) ?? []
        let positionInSiblings = siblingListItems.firstIndex(where: { $0 === markup }) ?? 0
        let position = positionInSiblings + parentMarkup.styleList.startingItemNumber
        let markerAttributedString = makeString(
            in: markup,
            string:parentMarkup.styleList.marker(forItemNumber: position),
            attributes: [
                .paragraphStyle: listItemParagraphStyle,
            ]
        )
        
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.string.utf16.count)) { attributes, range, _ in
            guard let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle else {
                attributedString.addAttribute(.paragraphStyle, value: listItemParagraphStyle, range: range)
                return
            }
            let updatedParagraphStyle = NSMutableParagraphStyle()
            updatedParagraphStyle.setParagraphStyle(paragraphStyle)
            updatedParagraphStyle.headIndent = listItemParagraphStyle.headIndent
            updatedParagraphStyle.defaultTabInterval = listItemParagraphStyle.defaultTabInterval
            updatedParagraphStyle.tabStops = listItemParagraphStyle.tabStops
            attributedString.addAttribute(.paragraphStyle, value: updatedParagraphStyle, range: range)
        }
        
        attributedString.insert(markerAttributedString, at: 0)
        attributedString.markSuffixTagBoundaryBreakline()
        
        return attributedString
    }
    
    func visit(_ markup: ListMarkup) -> Result {
        let attributedString = collectAttributedString(markup)
        let thisAttributedString = NSMutableAttributedString(attributedString: attributedString)
        thisAttributedString.markPrefixTagBoundaryBreakline()
        thisAttributedString.markSuffixTagBoundaryBreakline()
        
        return thisAttributedString
    }
    
    func visit(_ markup: ParagraphMarkup) -> Result {
        let attributedString = collectAttributedString(markup)
        let thisAttributedString = NSMutableAttributedString(attributedString: attributedString)
        thisAttributedString.markPrefixTagBoundaryBreakline()
        thisAttributedString.markSuffixTagBoundaryBreakline()
        
        return thisAttributedString
    }
    
    func visit(_ markup: UnderlineMarkup) -> Result {
        return collectAttributedString(markup)
    }
    
    func visit(_ markup: DeletelineMarkup) -> Result {
        return collectAttributedString(markup)
    }
    
    func visit(_ markup: TableColumnMarkup) -> Result {
        let attributedString = collectAttributedString(markup)
        let siblingColumns = markup.parentMarkup?.childMarkups.filter({ $0 is TableColumnMarkup }) ?? []
        let position = (siblingColumns.firstIndex(where: { $0 === markup }) ?? 0)
        
        var maxLength: Int? = markup.fixedMaxLength
        if maxLength == nil {
            if let tableRowMarkup = markup.parentMarkup as? TableRowMarkup,
               let firstTableRow = tableRowMarkup.parentMarkup?.childMarkups.first(where: { $0 is TableRowMarkup }) as? TableRowMarkup {
                let firstTableRowColumns = firstTableRow.childMarkups.filter({ $0 is TableColumnMarkup })
                if firstTableRowColumns.indices.contains(position) {
                    let firstTableRowColumnAttributedString = collectAttributedString(firstTableRowColumns[position])
                    let length = firstTableRowColumnAttributedString.string.utf16.count
                    maxLength = length
                }
            }
        }
        
        if let maxLength = maxLength {
            if attributedString.string.utf16.count > maxLength {
                attributedString.mutableString.setString(String(attributedString.string.prefix(maxLength))+"...")
            } else {
                attributedString.mutableString.setString(attributedString.string.padding(toLength: maxLength, withPad: " ", startingAt: 0))
            }
        }
        
        if position < siblingColumns.count - 1 {
            attributedString.append(makeString(in: markup, string: String(repeating: " ", count: markup.spacing)))
        }
        
        return attributedString
    }
    
    func visit(_ markup: TableRowMarkup) -> Result {
        let attributedString = collectAttributedString(markup)
        let thisAttributedString = NSMutableAttributedString(attributedString: attributedString)
        thisAttributedString.markSuffixTagBoundaryBreakline()

        return thisAttributedString
    }
    
    func visit(_ markup: TableMarkup) -> Result {
        let attributedString = collectAttributedString(markup)
        let thisAttributedString = NSMutableAttributedString(attributedString: attributedString)
        thisAttributedString.markPrefixTagBoundaryBreakline()
        thisAttributedString.markSuffixTagBoundaryBreakline()
        
        return thisAttributedString
    }
    
    func visit(_ markup: HeadMarkup) -> NSAttributedString {
        let attributedString = collectAttributedString(markup)
        let thisAttributedString = NSMutableAttributedString(attributedString: attributedString)
        thisAttributedString.markPrefixTagBoundaryBreakline()
        thisAttributedString.markSuffixTagBoundaryBreakline()
        
        return thisAttributedString
    }

    func visit(_ markup: ImageMarkup) -> NSAttributedString {
        let attributedString = collectAttributedString(markup)
        attributedString.insert(NSAttributedString(attachment: markup.attachment), at: 0)
        return attributedString
    }
    
    func visit(_ markup: BlockQuoteMarkup) -> NSAttributedString {
        let attributedString = collectAttributedString(markup)
        let thisAttributedString = NSMutableAttributedString(attributedString: attributedString)
        thisAttributedString.markPrefixTagBoundaryBreakline()
        thisAttributedString.markSuffixTagBoundaryBreakline()
        
        return thisAttributedString
    }
    
    func visit(_ markup: CodeMarkup) -> NSAttributedString {
        let attributedString = collectAttributedString(markup)
        return attributedString
    }
}

extension MarkupNSAttributedStringVisitor {
    // Find continues reduceable breakline and merge it.
    func reduceBreaklineInResultNSAttributedString(_ attributedString: NSAttributedString) -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        let totalLength = mutableAttributedString.string.utf16.count
        
        // merge tag Boundary Breakline, e.g. </p></div> -> /n/n -> /n
        var pre: (NSRange, NSAttributedString.Key.BreaklinePlaceholder?, [NSAttributedString.Key: Any])?
        mutableAttributedString.enumerateAttribute(.breaklinePlaceholder, in: NSMakeRange(0, totalLength)) { value, range, _ in
            if let breaklinePlaceholder = value as? NSAttributedString.Key.BreaklinePlaceholder {
                if range.location == 0 {
                    mutableAttributedString.deleteCharacters(in: range)
                } else if let pre = pre, let preBreaklinePlaceholder = pre.1 {
                    let preRange = pre.0
                    
                    switch (preBreaklinePlaceholder, breaklinePlaceholder) {
                    case (.breaklineTag, .tagBoundarySuffix):
                        // <br/></div> -> /n/n -> /n
                        mutableAttributedString.deleteCharacters(in: preRange)
                    case (.breaklineTag, .tagBoundaryPrefix):
                        // <br/><p> -> /n/n -> /n
                        mutableAttributedString.deleteCharacters(in: preRange)
                    case (.tagBoundarySuffix, .tagBoundarySuffix):
                        // </div></div> -> /n/n -> /n
                        mutableAttributedString.deleteCharacters(in: preRange)
                    case (.tagBoundarySuffix, .tagBoundaryPrefix):
                        // </div><p> -> /n/n -> /n
                        mutableAttributedString.deleteCharacters(in: preRange)
                    case (.tagBoundaryPrefix, .tagBoundaryPrefix):
                        // <div><p> -> /n/n -> /n
                        mutableAttributedString.deleteCharacters(in: preRange)
                    case (.tagBoundaryPrefix, .tagBoundarySuffix):
                        // <p></p> -> /n/n -> /n
                        mutableAttributedString.deleteCharacters(in: preRange)
                    default:
                        break
                    }
                }
                pre = (range, breaklinePlaceholder, [:])
            } else {
                pre = nil
            }
        }
        
        // Handle line breaks from breaklineTag
        // They create a new paragraph in the NSAttributedString, but not in the sense of the HTML content
        // This means no spacing between the new line and the previous one
        pre = nil
        mutableAttributedString.enumerateAttributes(in: NSRange(location: 0, length: mutableAttributedString.string.utf16.count), options: []) { attributes, range, _ in
            if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle,
               let brType = attributes[.breaklinePlaceholder] as? NSAttributedString.Key.BreaklinePlaceholder,
                brType == .breaklineTag
            {
                let updatedStyle = NSMutableParagraphStyle()
                updatedStyle.setParagraphStyle(paragraphStyle)
                updatedStyle.paragraphSpacingBefore = 0
                mutableAttributedString.addAttribute(.paragraphStyle, value: updatedStyle, range: range)
                
                if let previousRun = pre, let previousParagraphStyle = previousRun.2[.paragraphStyle] as? NSParagraphStyle {
                    let updatedStyle = NSMutableParagraphStyle()
                    updatedStyle.setParagraphStyle(previousParagraphStyle)
                    updatedStyle.paragraphSpacing = 0
                    mutableAttributedString.addAttribute(.paragraphStyle, value: updatedStyle, range: previousRun.0)
                }
            }
            pre = (range, nil, attributes)
        }
        
        // Remove placeholder attributes so the NSAttributedString can merge consecutive runs if they have the same attributes
        mutableAttributedString.enumerateAttribute(.breaklinePlaceholder, in: NSRange(location: 0, length: mutableAttributedString.string.utf16.count)) { _, range, _ in
            mutableAttributedString.removeAttribute(.breaklinePlaceholder, range: range)
        }
        
        return mutableAttributedString
    }
    
    func applyMarkupStyle(_ attributedString: NSAttributedString, with markupStyle: MarkupStyle?) -> NSAttributedString {
        guard let markupStyle = markupStyle else { return attributedString }
        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        
        if markupStyle.fontCase == .lowercase {
            mutableAttributedString.enumerateAttributes(in: NSRange(location: 0, length: mutableAttributedString.string.utf16.count), options: []) {_, range, _ in
                mutableAttributedString.replaceCharacters(in: range, with: (attributedString.string as NSString).substring(with: range).lowercased())
            }
        } else if markupStyle.fontCase == .uppercase {
            mutableAttributedString.enumerateAttributes(in: NSRange(location: 0, length: mutableAttributedString.string.utf16.count), options: []) {_, range, _ in
                mutableAttributedString.replaceCharacters(in: range, with: (mutableAttributedString.string as NSString).substring(with: range).uppercased())
            }
        }
        
        mutableAttributedString.addAttributes(markupStyle.render(), range: NSMakeRange(0, mutableAttributedString.string.utf16.count))
        return mutableAttributedString
    }
    
    func makeString(in markup: Markup, string: String, attributes attrs: [NSAttributedString.Key : Any]? = nil) -> NSAttributedString {
        let attributedString: NSAttributedString
        if let attrs = attrs, !attrs.isEmpty {
            attributedString = NSAttributedString(string: string, attributes: attrs)
        } else {
            attributedString = NSAttributedString(string: string)
        }
        return applyMarkupStyle(attributedString, with: collectMarkupStyle(markup))
    }
}

private extension MarkupNSAttributedStringVisitor {
    func collectAttributedString(_ markup: Markup) -> NSMutableAttributedString {
        // collect from downstream
        // Root -> Bold -> String("Bold")
        //      \
        //       > String("Test")
        // Result: Bold Test
        
        return markup.childMarkups.compactMap({ visit(markup: $0) }).reduce(NSMutableAttributedString()) { partialResult, attributedString in
            partialResult.append(attributedString)
            return partialResult
        }
    }
    
    func collectMarkupStyle(_ markup: Markup) -> MarkupStyle? {
        // collect from upstream
        // String("Test") -> Bold -> Italic -> Root
        // Result: style: Bold+Italic
        
        var currentMarkup: Markup? = markup.parentMarkup
        var currentStyle = components.value(markup: markup)
        while let thisMarkup = currentMarkup {
            guard let thisMarkupStyle = components.value(markup: thisMarkup) else {
                currentMarkup = thisMarkup.parentMarkup
                continue
            }

            if var thisCurrentStyle = currentStyle {
                thisCurrentStyle.fillIfNil(from: thisMarkupStyle)
                currentStyle = thisCurrentStyle
            } else {
                currentStyle = thisMarkupStyle
            }

            currentMarkup = thisMarkup.parentMarkup
        }
        
        if var currentStyle = currentStyle {
            currentStyle.fillIfNil(from: rootStyle)
            return currentStyle
        } else {
            return rootStyle
        }
    }
}

private extension NSAttributedString.Key {
    static let breaklinePlaceholder: NSAttributedString.Key = .init("breaklinePlaceholder")
    struct BreaklinePlaceholder: OptionSet {
        let rawValue: Int

        static let tagBoundaryPrefix = BreaklinePlaceholder(rawValue: 1)
        static let tagBoundarySuffix = BreaklinePlaceholder(rawValue: 2)
        static let breaklineTag = BreaklinePlaceholder(rawValue: 3)
    }
}

private extension NSMutableAttributedString {
    func markPrefixTagBoundaryBreakline() {
        self.insert(NSAttributedString(string: MarkupNSAttributedStringVisitor.breakLineSymbol, attributes: [.breaklinePlaceholder: NSAttributedString.Key.BreaklinePlaceholder.tagBoundaryPrefix]), at: 0)
    }
    
    func markSuffixTagBoundaryBreakline() {
        self.append(NSAttributedString(string: MarkupNSAttributedStringVisitor.breakLineSymbol, attributes: [.breaklinePlaceholder: NSAttributedString.Key.BreaklinePlaceholder.tagBoundarySuffix]))
    }
}
