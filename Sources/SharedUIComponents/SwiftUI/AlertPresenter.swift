//
//  Alert.swift
//

import SwiftUI

#if os(iOS)

public extension View {
    
    @available (iOS 15, *)
    func alerts(_ presenter: AlertPresenter) -> some View { modifier(AlertModifier()).environmentObject(presenter) }
}

@available (iOS 15, *)
public final class AlertPresenter: ObservableObject {
    
    fileprivate struct Info {
        let title: String
        let actions: ()->AnyView
        let message: ()->AnyView
    }
    
    public init() {}
    
    @Published fileprivate var alerts: [Info] = []
    
    public func show<A: View, M: View>(title: String = Bundle.main.infoDictionary!["CFBundleDisplayName"] as! String,
                                       @ViewBuilder _ message: @escaping ()->M,
                                       @ViewBuilder actions: @escaping ()->A) {
        alerts.append(.init(title: title, actions: { actions().asAny }, message: { message().asAny }))
    }
}

@available (iOS 15, *)
struct AlertModifier: ViewModifier {
    
    @EnvironmentObject var presenter: AlertPresenter
    
    func body(content: Content) -> some View {
        content.overlay {
            if let info = presenter.alerts.last {
                Color.clear.alert(info.title,
                                  isPresented: Binding(get: { true }, set: { _ in presenter.alerts.removeLast() }),
                                  actions: info.actions,
                                  message: info.message)
            }
        }
    }
}

#endif
