//
//  Collection.swift
//  
//
//  Created by Ilya Kuznetsov on 31/12/2022.
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

open class CollectionView: PlatformCollectionView, ListView {
    public typealias Cell = CollectionCell
    public typealias CellSize = CGSize
    public typealias ContainerCell = ContainerCollectionItem
    
    public var scrollView: PlatformScrollView {
        #if os(iOS)
        self
        #else
        enclosingScrollView!
        #endif
    }
    
    #if os(iOS)
    public override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        canCancelContentTouches = true
        delaysContentTouches = false
        backgroundColor = .clear
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .always
    }
    
    open override func touchesShouldCancel(in view: UIView) -> Bool {
        view is UIControl ? true : super.touchesShouldCancel(in: view)
    }
    #else
    open override var acceptsFirstResponder: Bool { false }
    
    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        (delegate as? Collection)?.visible = window != nil
    }
    #endif
}

public struct CollectionCell: ListCell {
    
    let info: CellInfo<PlatformCollectionCell, CGSize>
    
    #if os(macOS)
    public let doubleClick: (AnyHashable)->()
    #endif
    
    public let supports: (AnyHashable)->Bool
}

open class Collection: BaseList<CollectionView> {
    
    // when new items appears scroll aligns to the top
    public var expandsBottom: Bool = true
    
    public var staticCellSize: CGSize? {
        didSet { view.flowLayout?.itemSize = staticCellSize ?? .zero }
    }
    
    #if os(macOS)
    @objc private func doubleClickAction(_ sender: NSClickGestureRecognizer) {
        let location = sender.location(in: view)
        if let indexPath = view.indexPathForItem(at: location) {
            let item = items[indexPath.item]
            cell(item)?.doubleClick(item)
        }
    }
    #endif
    
    public required init(listView: CollectionView? = nil, emptyStateView: PlatformView) {
        super.init(listView: listView, emptyStateView: emptyStateView)
        delegate.add(self)
        delegate.addConforming([PlatformCollectionDelegate.self, PlatformCollectionDataSource.self])
        view.delegate = delegate as? PlatformCollectionDelegate
        view.dataSource = delegate as? PlatformCollectionDataSource
        
        #if os(macOS)
        view.isSelectable = true
        let recognizer = NSClickGestureRecognizer(target: self, action: #selector(doubleClickAction(_:)))
        recognizer.numberOfClicksRequired = 2
        recognizer.delaysPrimaryMouseButtonEvents = false
        view.addGestureRecognizer(recognizer)
        #endif
    }
    
    open override class func createDefaultView() -> CollectionView {
        #if os(iOS)
        let collection = CollectionView(frame: .zero, collectionViewLayout: VerticalLeftAlignedLayout())
        #else
        let scrollView = NSScrollView()
        let collection = CollectionView(frame: .zero)
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true
        scrollView.canDrawConcurrently = true
        
        collection.collectionViewLayout = VerticalLeftAlignedLayout()
        scrollView.documentView = collection
        scrollView.drawsBackground = true
        collection.backgroundColors = [.clear]
        #endif
        return collection
    }
    
    open override func reloadVisibleCells(excepting: Set<Int> = Set()) {
        #if os(iOS)
        let visibleCells = view.visibleCells
        #else
        let visibleCells = view.visibleItems()
        #endif
        visibleCells.forEach { cell in
            if let indexPath = view.indexPath(for: cell), !excepting.contains(indexPath.item) {
                let item = items[indexPath.item]
                
                if item as? PlatformView == nil {
                    self.cell(item)?.info.fill(item, cell)
                }
            }
        }
    }
    
    open override func update(_ items: [AnyHashable], animated: Bool, reloadCells: (Set<Int>) -> (), completion: @escaping () -> ()) {
        view.reload(animated: animated,
                    expandBottom: expandsBottom,
                    oldData: self.items,
                    newData: items,
                    updateObjects: reloadCells,
                    completion: completion)
    }
}
