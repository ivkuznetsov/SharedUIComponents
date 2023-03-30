//
//  UITableView+Reloading.swift
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

public extension PlatformTableView {
    
    func setNeedUpdateHeights() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateHeights), object: nil)
        perform(#selector(updateHeights), with: nil, afterDelay: 0)
    }
    
    @objc private func updateHeights() {
        beginUpdates()
        endUpdates()
    }
    
    #if os(iOS)
    static var cellsKey = "cellsKey"
    private var registeredCells: Set<String> {
        get { objc_getAssociatedObject(self, &PlatformCollectionView.cellsKey) as? Set<String> ?? Set() }
        set { objc_setAssociatedObject(self, &PlatformCollectionView.cellsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    #endif
    
    func createCell<T: PlatformTableCell>(for type: T.Type, source: CellSource = .nib) -> T {
        let className = type.classNameWithoutModule()
        
        let id: String
        switch source {
        case .nib:
            id = className
        case .code(reuseId: let reuseId):
            id = reuseId ?? className
        }
    #if os(iOS)
        if !registeredCells.contains(id) {
            switch source {
            case .nib:
                register(UINib(nibName: className, bundle: Bundle(for: type)), forCellReuseIdentifier: id)
            case .code:
                register(type, forCellReuseIdentifier: id)
            }
            registeredCells.insert(id)
        }
        return dequeueReusableCell(withIdentifier: id) as! T
        #else
        
        let itemId = NSUserInterfaceItemIdentifier(rawValue: id)
        let cell = (makeView(withIdentifier: itemId, owner: nil) ?? type.loadFromNib()) as! T
        cell.identifier = itemId
        return cell
        #endif
    }
    
    func enumerateVisibleCells(_ action: (IndexPath, BaseTableViewCell)->()) {
        #if os(iOS)
        visibleCells.forEach { cell in
            if let cell = cell as? BaseTableViewCell, let indexPath = indexPath(for: cell) {
                action(indexPath, cell)
            }
        }
        #else
        let rows = rows(in: visibleRect)
        for i in rows.location..<(rows.location + rows.length) {
            if let view = rowView(atRow: i, makeIfNecessary: false) as? BaseTableViewCell {
                action(IndexPath(item: i, section: 0), view)
            }
        }
        #endif
    }
    
    @available(iOS 15.0, *)
    func reloadVisibleCells() {
        let indexPaths = visibleCells.compactMap { indexPath(for: $0) }
        reconfigureRows(at: indexPaths)
    }
}
