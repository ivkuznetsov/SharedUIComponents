//
//  Additions.swift
//  
//
//  Created by Ilya Kuznetsov on 23/01/2023.
//

import SwiftUI

struct SlidePositionModifier: ViewModifier {
    let presented: Bool
    
    func body(content: Content) -> some View {
        content.offset(y: presented ? 0 : -50).opacity(presented ? 1 : 0)
    }
}

public extension AnyTransition {
    
    static var slideWithOpacity: AnyTransition {
        .modifier(active: SlidePositionModifier(presented: false),
                  identity: SlidePositionModifier(presented: true))
    }
}

public extension Binding {
    
    func optional() -> Binding<Value?> {
        Binding<Value?>(get: { wrappedValue }, set: { wrappedValue = $0! })
    }
}

extension CaseIterable where Self: Equatable {
    
    public var asIndex: Self.AllCases.Index {
        get { Self.allCases.firstIndex(of: self)! }
        set { self = Self.allCases[newValue] }
    }
}
