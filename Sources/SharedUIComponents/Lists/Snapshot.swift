//
//  File.swift
//  
//
//  Created by Ilya Kuznetsov on 12/01/2023.
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import SwiftUI

public typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<String, AnyHashable>

public struct Snapshot<View: ListView> {
    
    struct Section {
        
        struct Creation {
            let cell: View.Cell.Type
            let fill: (AnyHashable, PlatformView)->()
            let source: (AnyHashable)->CellSource
        }
        
        struct Actions {
            let action: (AnyHashable)->()
            let secondaryAction: ((AnyHashable)->())?
        }
        
        struct Features {
            let prefetch: ((AnyHashable)->PrefetchCancel?)?
            let additions: View.CellAdditions?
            let typeCheck: (AnyHashable)->Bool
        }
        
        let creation: Creation
        let actions: Actions
        let features: Features
        
        init<Item: Hashable, Cell>(_ item: Item.Type,
                                   cell: Cell.Type,
                                   source: ((Item)->CellSource)? = nil,
                                   fill: @escaping (Item, Cell)->(),
                                   action: ((Item)->())? = nil,
                                   secondaryAction: ((Item)->())? = nil,
                                   prefetch: ((Item)->PrefetchCancel)? = nil,
                                   additions: View.CellAdditions? = nil) {
            creation = .init(cell: cell as! View.Cell.Type,
                             fill: { fill($0 as! Item, $1 as! Cell) },
                             source: { source?($0 as! Item) ?? .nib })
            
            actions = .init(action: { action?($0 as! Item) },
                            secondaryAction: secondaryAction == nil ? nil : { secondaryAction!($0 as! Item) })
            
            features = .init(prefetch: prefetch == nil ? nil : { prefetch!($0 as! Item) },
                             additions: additions,
                             typeCheck: { $0 is Item })
        }
    }
    
    public static func with(_ fill: (inout Snapshot<View>)->()) -> Snapshot<View> {
        var snapshot = Snapshot<View>()
        fill(&snapshot)
        return snapshot
    }
    
    private(set) var sections: [Section] = []
    public private(set) var data = DataSourceSnapshot()
    private var sectionIds = Set<String>()
    
    public init() {}
    
    var hasPrefetch: Bool { sections.contains(where: { $0.features.prefetch != nil }) }
    
    private var viewInfo: Section { Section(PlatformView.self,
                                     cell: View.Container.self,
                                     source: { .code(reuseId: "\($0.hashValue)") },
                                     fill: { $1.attach(viewToAttach: $0) }) }
    
    #if os(iOS)
    private var viewContainerInfo: Section { Section(ViewContainer.self,
                                                     cell: View.Container.self,
                                                     source: { .code(reuseId: $0.reuseId) },
                                                     fill: {
        $1.contentConfiguration = $0.configuration
    }) }
    #endif
    
    mutating public func addSection(_ view: PlatformView) {
        addSection([view])
    }
    
    mutating public func addSection(_ views: [PlatformView]) {
        addSection(views, section: viewInfo)
    }
    
    #if os(iOS)
    mutating public func addSection<T: SwiftUI.View>(_ view: T) {
        addSection([view.inContainer()])
    }
    
    mutating public func addSection(_ view: ViewContainer) {
        addSection([view])
    }
    
    mutating public func addSection(_ views: [ViewContainer]) {
        addSection(views, section: viewContainerInfo)
    }
    #endif
    
    mutating func add(_ item: AnyHashable, sectionId: String) {
        data.appendItems([item], toSection: sectionId)
    }
    
    mutating public func addViewSectionId(_ id: String) {
        data.appendSections([id])
        sections.append(viewInfo)
    }
    
    mutating func addSection<T: Hashable>(_ items: [T], section: Section) {
        let className = String(describing: T.self)
        var sectionId = className
        var counter = 0
        while sectionIds.contains(sectionId) {
            counter += 1
            sectionId = className + "\(counter)"
        }
        sectionIds.insert(sectionId)
        data.appendSections([sectionId])
        data.appendItems(items, toSection: sectionId)
        sections.append(section)
    }
    
    func info(_ indexPath: IndexPath) -> (section: Section, item: AnyHashable)? {
        if let section = sections[safe: indexPath.section],
           let sectionId = data.sectionIdentifiers[safe: indexPath.section],
           let item = data.itemIdentifiers(inSection: sectionId)[safe: indexPath.item] {
            return (section, item)
        }
        return nil
    }
}

public extension DataSourceSnapshot {
    
    mutating func add<T: Hashable>(_ items: [T]) {
        let sectionName = String(describing: T.self)
        appendSections([sectionName])
        appendItems(items, toSection: sectionName)
    }
}
