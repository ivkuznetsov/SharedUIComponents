//
//  BaseTableViewCell.swift
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

open class BaseTableViewCell: PlatformTableCell {
    
    #if os(iOS)
    open override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = UIColor(white: 0.5, alpha: 0.1)
    }
    
    open override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        reloadSelection(animated: animated)
    }
    
    open override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        reloadSelection(animated: animated)
    }
    
    open func reloadSelection(animated: Bool) { }
    #else
    
    open override func drawSeparator(in dirtyRect: NSRect) {
        if !isSelected && !isNextRowSelected {
            super.drawSeparator(in: dirtyRect)
        }
    }

    open override var isNextRowSelected: Bool {
        get { super.isNextRowSelected }
        set {
            super.isNextRowSelected = newValue
            self.needsDisplay = true
        }
    }
    #endif
}
