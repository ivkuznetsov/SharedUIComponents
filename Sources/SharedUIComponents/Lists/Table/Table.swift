//
//  Table.swift
//  
//
//  Created by Ilya Kuznetsov on 31/12/2022.
//

#if os(iOS)
import UIKit
import SwiftUI
#else
import AppKit
#endif

extension PlatformTableCell: WithConfiguration {
    
    public var view: PlatformView { self }
}

#if os(macOS)
public class TableView: PlatformTableView {
    
    override public func drawGrid(inClipRect clipRect: NSRect) { }
}
#endif

public struct TableCell {
    
    #if os(iOS)
    public enum Editor {
        case delete(()->())
        case insert(()->())
        case actions(()->[UIContextualAction])
        
        var style: UITableViewCell.EditingStyle {
            switch self {
            case .delete(_): return .delete
            case .insert(_): return .insert
            case .actions(_): return .none
            }
        }
    }
    
    let editor: (AnyHashable)->Editor?
    
    #else
    let menuItems: (AnyHashable)->[NSMenuItem]
    #endif
}

extension PlatformTableDataSource: DataSource {
    
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

extension PlatformTableView: ListView {
    public typealias CellAdditions = TableCell
    public typealias Cell = BaseTableViewCell
    public typealias Content = PlatformTableDataSource
    public typealias Container = ContainerTableCell
    
    public var scrollView: PlatformScrollView {
        #if os(iOS)
        self
        #else
        enclosingScrollView!
        #endif
    }
}

public extension Snapshot where View == PlatformTableView {
    
    #if os(iOS)
    mutating func addSection<Cell: PlatformTableCell, Item: Hashable>(_ items: [Item],
                                                                      cell: Cell.Type,
                                                                      source: ((Item)->CellSource)? = nil,
                                                                      fill: @escaping (Item, Cell)->(),
                                                                      action: ((Item)->())? = nil,
                                                                      longPress: ((Item)->())? = nil,
                                                                      editor: ((Item)->TableCell.Editor?)? = nil,
                                                                      prefetch: ((Item)->PrefetchCancel)? = nil) {
        addSection(items, section: .init(Item.self,
                                         cell: cell,
                                         source: source,
                                         fill: fill,
                                         action: action,
                                         secondaryAction: longPress,
                                         prefetch: prefetch,
                                         additions: .init(editor: { editor?($0 as! Item) })))
    }

    mutating func addSection<Item: Hashable, Content: SwiftUI.View>(_ items: [Item],
                                             fill: @escaping (Item)-> Content,
                                             longPress: ((Item)->())? = nil,
                                             prefetch: ((Item)->PrefetchCancel)? = nil,
                                             editor: ((Item)->TableCell.Editor?)? = nil) {
        addSection(items, section: .init(Item.self,
                                         cell: ContainerTableCell.self,
                                         source: { _ in .code(reuseId: String(describing: Item.self)) },
                                         fill: { item, cell in
            cell.automaticallyUpdatesContentConfiguration = false
            if #available(iOS 16, *) {
                cell.contentConfiguration = UIHostingConfiguration { fill(item) }.margins(.all, 0)
            } else {
                cell.contentConfiguration = UIHostingConfigurationBackport { fill(item).ignoresSafeArea() }.margins(.all, 0)
            }
        }, secondaryAction: longPress, prefetch: prefetch, additions: .init(editor: { editor?($0 as! Item) })))
    }

    #else
    mutating func add<Cell: PlatformTableCell, Item: Hashable>(_ items: [Item],
                                                                    cell: Cell.Type,
                                                                    source: ((Item)->CellSource)? = nil,
                                                                    fill: @escaping (Item, Cell)->(),
                                                                    action: ((Item)->())? = nil,
                                                                    doubleClick: ((Item)->())? = nil) {
        addSection(items, section: .init(Item.self,
                                         cell: cell,
                                         source: source,
                                         fill: fill,
                                         action: action,
                                         secondaryAction: doubleClick))
    }
    #endif
}

@MainActor
public final class Table: ListContainer<PlatformTableView>, PlatformTableDelegate, PrefetchTableProtocol {
    
    #if os(macOS)
    public var deselectedAll: (()->())?
    
    /*public var selectedItem: AnyHashable? {
        set {
            if let item = newValue, let index = items.firstIndex(of: item) {
                FirstResponderPreserver.performWith(view.window) {
                    view.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                }
            } else {
                view.deselectAll(nil)
            }
        }
        get { item(IndexPath(item: view.selectedRow, section: 0)) }
    }*/
    #endif
    
    static func createDefaultView() -> PlatformTableView {
        #if os(iOS)
        let table = PlatformTableView(frame: CGRect.zero, style: .plain)
        table.backgroundColor = .clear
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 150
        
        table.subviews.forEach {
            if let view = $0 as? UIScrollView {
                view.delaysContentTouches = false
            }
        }
        #else
        let scrollView = NSScrollView()
        let table = TableView(frame: .zero)
        
        scrollView.documentView = table
        scrollView.drawsBackground = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        table.backgroundColor = .clear
        table.intercellSpacing = .zero
        table.gridStyleMask = .solidHorizontalGridLineMask
        table.headerView = nil
        scrollView.retained(by: self)
        #endif
        return table
    }
    
    public required init(listView: PlatformTableView? = nil) {
        super.init(listView: listView ?? Self.createDefaultView())
        
        #if os(iOS)
        dataSource = PlatformTableDataSource(tableView: view) { [unowned self] tableView, indexPath, item in
            guard let info = self.snapshot.info(indexPath)?.section else {
                fatalError("Please specify cell for \(item)")
            }
            let cell = view.createCell(for: info.cell, source: info.source(item))
            info.fill(item, cell)
            return cell
        }
        #else
        dataSource = PlatformTableDataSource(tableView: view) { tableView, tableColumn, row, identifier in
            NSView()
        }
        dataSource.rowViewProvider = { [unowned self] tableView, index, item in
            guard let info = self.snapshot.info(IndexPath(item: index, section: 0))?.section else {
                fatalError("Please specify cell for \(item)")
            }
            let cell = view.createCell(for: info.cell, source: info.source(item))
            info.fill(item, cell)
            return cell
        }
        #endif
        
        delegate.add(self)
        delegate.addConforming(PlatformTableDelegate.self)
        view.delegate = delegate as? PlatformTableDelegate
        
        #if os(iOS)
        view.tableFooterView = UIView()
        #else
        //view.menu = NSMenu()
        //view.menu?.delegate = self
        view.wantsLayer = true
        view.target = self
        view.usesAutomaticRowHeights = true
        #endif
    }
    
    #if os(iOS)
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let info = snapshot.info(indexPath) {
            info.section.action(info.item)
        }
    }
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if let info = snapshot.info(indexPath), let editor = info.section.additions?.editor(info.item) {
            switch editor {
            case .delete(let action): action()
            case .insert(let action): action()
            default: break
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if let info = snapshot.info(indexPath), let editor = info.section.additions?.editor(info.item),
           case .actions(let actions) = editor {
            let configuration = UISwipeActionsConfiguration(actions: actions())
            configuration.performsFirstActionWithFullSwipe = false
            return configuration
        }
        return nil
    }
    
    public func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if let info = snapshot.info(indexPath), let editor = info.section.additions?.editor(info.item) {
            return editor.style
        }
        return .none
    }
    
    public func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        prefetch(indexPaths)
    }
    
    public func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        cancelPrefetch(indexPaths)
    }
    #else
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        let selected = view.selectedRowIndexes
        
        if selected.isEmpty {
            deselectedAll?()
        } else {
            selected.forEach {
                view.deselectRow($0)
                if let info = snapshot.info(.init(item: $0, section: 0)) {
                    info.section.action(info.item)
                }
            }
        }
    }
    /*
    @objc public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let info = snapshot.info(.init(index: view.clickedRow)) {
            info.section.
        }
        
        if let item = item(.init(row: view.clickedRow, section: 0)) {
            cells.info(item)?.menuItems(item).forEach { menu.addItem($0) }
        }
    }*/
    #endif
}
