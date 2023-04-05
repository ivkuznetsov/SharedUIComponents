//
//  SheetPresenter.swift
//  Ivory
//
//  Created by Ilya Kuznetsov on 18/01/2023.
//

import SwiftUI
import Foundation

public final class SheetPresenter: ObservableObject {
    
    struct Sheet: Identifiable, Equatable {
        let id = UUID()
        let view: AnyView
        
        static func == (lhs: SheetPresenter.Sheet, rhs: SheetPresenter.Sheet) -> Bool { lhs.id == rhs.id }
    }
    
    public init() {}
    
    @Published var sheets: [Sheet] = []
    
    public func present<Sheet: View>(@ViewBuilder sheet: ()->Sheet) {
        sheets.append(.init(view: sheet().asAny))
    }
}

fileprivate struct SheetPresenterModifier: ViewModifier {
    
    @ObservedObject var presenter: SheetPresenter
    @Binding var sheet: SheetPresenter.Sheet?
    
    init(presenter: SheetPresenter) {
        self.presenter = presenter
        self._sheet = Binding(get: { presenter.sheets.last }, set: { _ in _ = presenter.sheets.popLast() })
    }
    
    func body(content: Content) -> some View {
        content.sheet(item: $sheet) { $0.view }
    }
}

public extension View {
    
    func sheets(_ presenter: SheetPresenter) -> some View {
        modifier(SheetPresenterModifier(presenter: presenter)).environmentObject(presenter)
    }
}
