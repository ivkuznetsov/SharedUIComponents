//
//  ContainerTableCell.swift
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

public protocol ContainedView {
    
    #if os(iOS)
    func wasReattached()
    #endif
}

public final class ContainerTableCell: BaseTableViewCell, ContainerCell {
    
    fileprivate var attachedView: PlatformView? {
        #if os(iOS)
        contentView.subviews.last
        #else
        subviews.last
        #endif
    }
    
    public func attach(viewToAttach: PlatformView) {
        if viewToAttach != attachedView {
            #if os(iOS)
            backgroundColor = .clear
            #endif
            attachedView?.removeFromSuperview()
            attach(viewToAttach)
        }
        
        #if os(iOS)
        (viewToAttach as? ContainedView)?.wasReattached()
        #endif
    }
}
