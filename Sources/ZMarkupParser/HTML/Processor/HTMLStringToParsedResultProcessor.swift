//
//  HTMLStringToParsedResultProcessor.swift
//  
//
//  Created by https://zhgchg.li on 2023/2/9.
//

import Foundation

final class HTMLStringToParsedResultProcessor: ParserProcessor {
    typealias From = NSAttributedString
    typealias To = [HTMLParsedResult]
    
    // e.g 1. <br rel="test"/>
    // match.range(at: 2): br
    // match.range(at: 3):  rel="test"
    // match.range(at: 6): /
    // e.g 2. <span style="color:#ff00ff;">
    // match.range(at: 2) span
    // match.range(at: 3):  style="color:#ff00ff;"
    // e.g 3. </span>
    // match.range(at: 1) /
    // match.range(at: 2) span
    static let htmlTagRegexPattern: String = #"<(?:(\/)?([A-Za-z]+)((?:\s*(\w+)\s*=\s*(["|']).*?\5)*)\s*(\/)?>)"#
    
    // e.g. href="https://zhgchg.li"
    // match.range: href="https://zhgchg.li"
    // match.range(at: 1): href
    // match.range(at: 3): https://zhgchg.li
    static let htmlTagAttributesRegexPattern: String = #"\s*((?:\w+))\s*={1}\s*(["|']){1}(.*?)\2\s*"#
    
    // will match:
    // <!--Test--> / <\!DOCTYPE html> / ` \n `
    static let htmlCommentOrDocumentHeaderRegexPattern: String = #"(\<\!\-\-(?:.*)\-\-\>)|(\<\!DOCTYPE(?:[^>]*)\>)|(\<\!doctype(?:[^>]*)\>)|(\s*\n\s*)"#
        
    func process(from: From) -> To {
        var items: To = []
        guard let regxr = ParserRegexr(attributedString: from, pattern: Self.htmlTagRegexPattern) else {
            return items
        }
        
        regxr.enumerateMatches(using: { match in
            switch match {
            case .rawString(let rawStringAttributedString):
                let commentAndDocumentHeaderRegxer = ParserRegexr(attributedString: rawStringAttributedString, pattern: Self.htmlCommentOrDocumentHeaderRegexPattern)
                commentAndDocumentHeaderRegxer?.enumerateMatches(using: { commentAndDocumentHeaderMatch in
                    switch commentAndDocumentHeaderMatch {
                    case .match:
                        // match <!--HTML Comment--> or <!DOCTYPE html> or ` \n `
                        // ignore it
                        break
                    case .rawString(let stringAttributedString):
                        items.append(.rawString(stringAttributedString))
                    }
                })
            case .match(let matchResult):
                let matchAttributedString = matchResult.attributedString(from, with: matchResult.range)
                let matchTag = matchResult.attributedString(from, at: 2)?.string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let matchIsEndTag = matchResult.attributedString(from, at: 1)?.string.trimmingCharacters(in: .whitespacesAndNewlines) == "/"
                let matchTagAttributes = parseAttributes(matchResult.attributedString(from, at: 3))
                let matchIsSelfClosingTag = matchResult.attributedString(from, at: 6)?.string.trimmingCharacters(in: .whitespacesAndNewlines) == "/"
                
                if let matchAttributedString = matchAttributedString, let matchTag = matchTag {
                    if matchIsSelfClosingTag {
                        // <br/>
                        items.append(.selfClosing(.init(tagName: matchTag, tagAttributedString: matchAttributedString, attributes: matchTagAttributes)))
                    } else {
                        // <a> or </a>
                        if matchIsEndTag {
                            // </a>
                            items.append(.close(.init(tagName: matchTag, token: UUID().uuidString)))
                        } else {
                            // <a>
                            items.append(.start(.init(tagName: matchTag, tagAttributedString: matchAttributedString, attributes: matchTagAttributes, token: UUID().uuidString)))
                        }
                    }
                }
            }
        })
        return items
    }

    
    func parseAttributes(_ attributedString: NSAttributedString?) -> [String: String]? {
        guard let attributedString = attributedString else { return nil }
        guard let regxr = ParserRegexr(attributedString: attributedString, pattern: Self.htmlTagAttributesRegexPattern) else {
            return nil
        }
        
        var attributes: [String: String] = [:]
        
        regxr.enumerateMatches { matchType in
            switch matchType {
            case .rawString:
                break
            case .match(let matchResult):
                if let key = matchResult.attributedString(attributedString, at: 1)?.string,
                   let value = matchResult.attributedString(attributedString, at: 3)?.string {
                    attributes[key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return attributes
    }
}
