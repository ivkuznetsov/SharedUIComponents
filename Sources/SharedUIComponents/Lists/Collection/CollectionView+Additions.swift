//
//  CollectionView.swift
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

public extension PlatformCollectionView {
    
    static var cellsKey = "cellsKey"
    
    #if os(iOS)
    private var registeredCells: Set<String> {
        get { objc_getAssociatedObject(self, &PlatformCollectionView.cellsKey) as? Set<String> ?? Set() }
        set { objc_setAssociatedObject(self, &PlatformCollectionView.cellsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    #else
    private var registeredCells: Set<String> {
        get { objc_getAssociatedObject(self, &PlatformCollectionView.cellsKey) as? Set<String> ?? Set() }
        set { objc_setAssociatedObject(self, &PlatformCollectionView.cellsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    #endif
    
    func createCell<T: PlatformCollectionCell>(for type: T.Type, source: CellSource = .nib, at indexPath: IndexPath) -> T {
        let className = type.classNameWithoutModule()
        
        let id: String
        switch source {
        case .nib:
            id = className
        case .code(reuseId: let reuseId):
            id = reuseId ?? className
        }
        
        if !registeredCells.contains(id) {
            switch source {
            case .nib:
                #if os(iOS)
                register(UINib(nibName: className, bundle: Bundle(for: type)), forCellWithReuseIdentifier: id)
                #else
                register(NSNib(nibNamed: id, bundle: Bundle(for: type)), forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: id))
                #endif
            case .code:
                #if os(iOS)
                register(type, forCellWithReuseIdentifier: id)
                #else
                register(type, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: id))
                #endif
            }
            registeredCells.insert(id)
        }
        #if os(iOS)
        return dequeueReusableCell(withReuseIdentifier: id, for: indexPath) as! T
        #else
        return makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: id), for: indexPath) as! T
        #endif
    }
    
    func enumerateVisibleCells(_ action: (IndexPath, UICollectionViewCell)->()) {
        #if os(iOS)
        let visibleCells = visibleCells
        #else
        let visibleCells = visibleItems()
        #endif
        visibleCells.forEach { cell in
            if let indexPath = indexPath(for: cell) {
                action(indexPath, cell)
            }
        }
    }
}
