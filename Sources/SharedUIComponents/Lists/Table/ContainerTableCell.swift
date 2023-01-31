//
//  ContainerTableCell.swift
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

public protocol ContainedView {
    
    func wasReattached()
}

public class ContainerTableCell: BaseTableViewCell, ContainerCell {
    
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
        (viewToAttach as? ContainedView)?.wasReattached()
    }
}
