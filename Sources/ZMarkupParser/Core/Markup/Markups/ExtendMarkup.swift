//
//  ExtendMarkup.swift
//  
//
//  Created by https://zhgchg.li on 2023/2/12.
//

import Foundation

final class ExtendMarkup: Markup {
    weak var parentMarkup: Markup? = nil
    var childMarkups: [Markup] = []

    func accept<V>(_ visitor: V) -> V.Result where V : MarkupVisitor {
        return visitor.visit(self)
    }
}
