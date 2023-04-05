//
//  ContainerCollectionCell.swift
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

public final class ContainerCollectionItem: PlatformCollectionCell, ContainerCell {
    
    fileprivate var attachedView: PlatformView? {
        #if os(iOS)
        contentView.subviews.last
        #else
        view.subviews.last
        #endif
    }
    
   // public override func prepareForReuse() { // fix this later
        // prevent of stopping animation of activity indicator
    //}
    
    public func attach(viewToAttach: PlatformView) {
        if viewToAttach != attachedView {
            attachedView?.removeFromSuperview()
            
            viewToAttach.translatesAutoresizingMaskIntoConstraints = false
            #if os(iOS)
            let container = contentView
            #else
            let container = view
            #endif
            
            container.addSubview(viewToAttach)
            container.leftAnchor.constraint(equalTo: viewToAttach.leftAnchor).isActive = true
            container.rightAnchor.constraint(equalTo: viewToAttach.rightAnchor).isActive = true
            container.topAnchor.constraint(equalTo: viewToAttach.topAnchor).isActive = true
            
            let bottom = container.bottomAnchor.constraint(equalTo: viewToAttach.bottomAnchor)
            bottom.priority = .init(500)
            bottom.isActive = true
        }
        
        #if os(iOS)
        (viewToAttach as? ContainedView)?.wasReattached()
        #endif
    }
    
    #if os(macOS)
    override public func loadView() {
        view = NSView()
    }
    #endif
}
