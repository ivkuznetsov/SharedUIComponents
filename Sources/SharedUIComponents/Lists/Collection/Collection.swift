//
//  Collection.swift
//  
//
//  Created by Ilya Kuznetsov on 31/12/2022.
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

extension PlatformCollectionCell: WithConfiguration {
    
    #if os(iOS)
    public var view: UIView { self }
    #endif
}

extension PlatformCollectionDataSource: DataSource {
    
    public func apply(_ snapshot: DataSourceSnapshot, animated: Bool) async {
        if #available(iOS 15, *) {
            await apply(snapshot, animatingDifferences: animated)
        } else {
            await withCheckedContinuation { continuation in
                apply(snapshot, animatingDifferences: animated) {
                    continuation.resume()
                }
            }
        }
    }
}

public struct CollectionCell {
    let layout: (NSCollectionLayoutEnvironment)->NSCollectionLayoutSection
    
    init(layout: ((NSCollectionLayoutEnvironment)->NSCollectionLayoutSection)?) {
        self.layout = layout ?? { .grid($0) }
    }
}

open class CollectionView: PlatformCollectionView, ListView {
    public typealias CellAdditions = CollectionCell
    public typealias Cell = PlatformCollectionCell
    public typealias Content = PlatformCollectionDataSource
    public typealias Container = ContainerCollectionItem
    
    public var scrollView: PlatformScrollView {
        #if os(iOS)
        self
        #else
        enclosingScrollView!
        #endif
    }
    
    #if os(iOS)
    public required override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
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
        contentInsetAdjustmentBehavior = .automatic
        showsHorizontalScrollIndicator = false
    }
    
    open override func touchesShouldCancel(in view: UIView) -> Bool {
        view is UIControl ? true : super.touchesShouldCancel(in: view)
    }
    
    #else
    open override var acceptsFirstResponder: Bool { false }
    #endif
}

public extension Snapshot where View == CollectionView {
    
    typealias SectionLayout = (NSCollectionLayoutEnvironment)->NSCollectionLayoutSection
    
    #if os(iOS)
    mutating func addSection<Cell: PlatformCollectionCell, Item: Hashable>(_ items: [Item],
                                                                           cell: Cell.Type,
                                                                           source: ((Item)->CellSource)? = nil,
                                                                           fill: @escaping (Item, Cell)->(),
                                                                           action: ((Item)->())? = nil,
                                                                           longPress: ((Item)->())? = nil,
                                                                           prefetch: ((Item)->PrefetchCancel)? = nil,
                                                                           layout: SectionLayout? = nil) {
        addSection(items, section: .init(Item.self,
                                         cell: cell,
                                         source: source,
                                         fill: fill,
                                         action: action,
                                         secondaryAction: longPress,
                                         prefetch: prefetch,
                                         additions: .init(layout: layout)))
    }

    mutating func addSection<Item: Hashable, Content: SwiftUI.View>(_ items: [Item],
                                             fill: @escaping (Item)-> Content ,
                                             longPress: ((Item)->())? = nil,
                                             prefetch: ((Item)->PrefetchCancel)? = nil,
                                             layout: SectionLayout? = nil) {
        addSection(items, section: .init(Item.self,
                                         cell: ContainerCollectionItem.self,
                                         source: { _ in .code(reuseId: String(describing: Item.self)) },
                                         fill: { item, cell in
            if #available(iOS 16, *) {
                cell.contentConfiguration = UIHostingConfiguration { fill(item) }.margins(.all, 0)
            } else {
                cell.contentConfiguration = UIHostingConfigurationBackport { fill(item).ignoresSafeArea() }.margins(.all, 0)
            }
        }, secondaryAction: longPress, prefetch: prefetch, additions: .init(layout: layout)))
    }

    #else
    mutating func add<Cell: PlatformCollectionCell, Item: Hashable>(_ items: [Item],
                                                                    cell: Cell.Type,
                                                                    source: ((Item)->CellSource)? = nil,
                                                                    fill: @escaping (Item, Cell)->(),
                                                                    action: ((Item)->())? = nil,
                                                                    doubleClick: ((Item)->())? = nil,
                                                                    layout: SectionLayout? = nil) {
        addSection(items, section: .init(Item.self,
                                         cell: cell,
                                         source: source,
                                         fill: fill,
                                         action: action,
                                         secondaryAction: doubleClick,
                                         additions: .init(layout: layout)))
    }
    #endif
}

class CollectionViewLayout: PlatformCollectionLayout {
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        collectionView?.bounds.size ?? newBounds.size != newBounds.size
    }
}

@MainActor
public final class Collection: ListContainer<CollectionView>, PlatformCollectionDelegate, PrefetchCollectionProtocol {
    
    public static func createDefaultView() -> CollectionView {
        #if os(iOS)
        let collection = CollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        #else
        let scrollView = NSScrollView()
        let collection = CollectionView(frame: .zero)
        collection.isSelectable = true
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true
        scrollView.canDrawConcurrently = true
        scrollView.documentView = collection
        scrollView.drawsBackground = true
        collection.backgroundColors = [.clear]
        #endif
        return collection
    }
    
    public required init(listView: CollectionView? = nil) {
        super.init(listView: listView ?? Self.createDefaultView())
        
        dataSource = PlatformCollectionDataSource(collectionView: view) { [unowned self] collection, indexPath, item in
            var info = self.snapshot.info(indexPath)?.section
            
            if info?.features.typeCheck(item) != true {
                info = self.oldSnapshot?.info(indexPath)?.section
                
                if info?.features.typeCheck(item) != true {
                    fatalError("No info for the item")
                }
            }
            
            let cell = self.view.createCell(for: info!.creation.cell,
                                            source: info!.creation.source(item), at: indexPath)
            info!.creation.fill(item, cell.view)
            return cell
        }
        
        let layout = CollectionViewLayout { [unowned self] index, environment in
            if let layout = self.snapshot.sections[safe: index]?.features.additions?.layout {
                return layout(environment)
            }
            return .grid(environment)
        }
        #if os(iOS)
        view.setCollectionViewLayout(layout, animated: false)
        #else
        view.collectionViewLayout = layout
        #endif
        
        delegate.addConforming(PlatformCollectionDelegate.self)
        delegate.add(self)
        view.delegate = delegate as? PlatformCollectionDelegate
    }
    
    #if os(iOS)
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if let info = snapshot.info(indexPath) {
            info.section.actions.action(info.item)
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        prefetch(indexPaths)
    }
    
    public func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        cancelPrefetch(indexPaths)
    }
    #else
    public func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        collectionView.deselectAll(nil)
        indexPaths.forEach {
            if let info = snapshot.info($0) {
                info.section.action(info.item)
            }
        }
    }
    #endif
}
