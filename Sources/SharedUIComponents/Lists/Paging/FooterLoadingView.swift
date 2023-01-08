//
//  FooterLoadingView.swift
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

open class FooterLoadingView: PlatformView {

    public init(state: LoadingState) {
        #if os(iOS)
        let indicatorView = UIActivityIndicatorView(style: .medium)
        let retryButton = UIButton(type: .system)
        retryButton.setTitle("Retry", for: .normal)
        #else
        let indicatorView = NSProgressIndicator()
        indicatorView.style = .spinning
        let retryButton = NSButton()
        retryButton.bezelStyle = .texturedRounded
        retryButton.title = "Retry"
        #endif
        super.init(frame: .zero)
        
        #if os(iOS)
        retryButton.addTarget(self, action: #selector(retryAction), for: .touchUpInside)
        #else
        retryButton.target = self
        retryButton.action = #selector(retryAction)
        #endif
        attach(retryButton, position: .center)
        attach(indicatorView, position: .center)
        
        let constraint = heightAnchor.constraint(equalToConstant: 50)
        constraint.priority = .init(900)
        constraint.isActive = true
        
        state.$value.sink { state in
            if case .failed(_) = state {
                retryButton.isHidden = false
            } else {
                retryButton.isHidden = true
            }
            #if os(iOS)
            if state == .loading {
                indicatorView.startAnimating()
            } else {
                indicatorView.stopAnimating()
            }
            #else
            if state == .loading {
                indicatorView.startAnimation(nil)
            } else {
                indicatorView.stopAnimation(nil)
            }
            #endif
        }.retained(by: self)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var retry: (()->())?
    
    @objc private func retryAction() {
        retry?()
    }
}
