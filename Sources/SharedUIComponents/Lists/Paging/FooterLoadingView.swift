//
//  FooterLoadingView.swift
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import Combine

public class FooterLoadingView: PlatformView, ContainedView {

    #if os(iOS)
    public let indicatorView = UIActivityIndicatorView(style: .medium)
    public private(set) lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Retry", for: .normal)
        button.addTarget(self, action: #selector(retryAction), for: .touchUpInside)
        return button
    }()
    
    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if state?.value == .loading {
            indicatorView.startAnimating()
        }
    }
    
    open override func didMoveToWindow() {
        super.didMoveToWindow()
        if state?.value == .loading {
            indicatorView.startAnimating()
        }
    }
    
    public func wasReattached() {
        if state?.value == .loading {
            indicatorView.startAnimating()
        }
    }
    #else
    public let indicatorView: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        return indicator
    }()
    
    public lazy var retryButton: NSButton = {
        let button = NSButton()
        button.bezelStyle = .texturedRounded
        button.title = "Retry"
        button.target = self
        button.action = #selector(retryAction)
        return button
    }()
    #endif
    
    private var observer: AnyCancellable?
    
    private var state: LoadingState? {
        didSet {
            observer = state?.$value.sink { [weak self] state in
                if case .failed(_) = state {
                    self?.retryButton.isHidden = false
                } else {
                    self?.retryButton.isHidden = true
                }
                #if os(iOS)
                if state == .loading {
                    self?.indicatorView.startAnimating()
                } else {
                    self?.indicatorView.stopAnimating()
                }
                #else
                if state == .loading {
                    self?.indicatorView.startAnimation(nil)
                } else {
                    self?.indicatorView.stopAnimation(nil)
                }
                #endif
            }
        }
    }
    
    public func observe(_ state: LoadingState?) {
        self.state = state
    }
    
    public init() {
        super.init(frame: .zero)
        attach(retryButton, position: .center)
        attach(indicatorView, position: .center)
        
        let constraint = heightAnchor.constraint(equalToConstant: 50)
        constraint.priority = .init(900)
        constraint.isActive = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var retry: (()->())?
    
    @objc private func retryAction() {
        retry?()
    }
}
