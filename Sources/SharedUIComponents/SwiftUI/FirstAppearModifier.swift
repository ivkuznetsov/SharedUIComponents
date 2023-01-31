//
//  FirstAppear.swift
//  
//
//  Created by Ilya Kuznetsov on 23/01/2023.
//

import SwiftUI

public extension View {
    
    func onFirstAppear(_ action: @escaping ()->()) -> some View {
        modifier(FirstAppearModifier(action: action))
    }
}

public struct FirstAppearModifier: ViewModifier {
    
    @State private var didAppear = false
    
    let action: ()->()
    
    init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public func body(content: Content) -> some View {
        content.onAppear {
            if !didAppear {
                didAppear = true
                action()
            }
        }
    }
}
