//
//  Table.swift
//  
//
//  Created by Ilya Kuznetsov on 31/12/2022.
//

#if os(iOS)
import UIKit
#else
import AppKit

public class NoEmptyCellsTableView: NSTableView {
    override public func drawGrid(inClipRect clipRect: NSRect) { }
    
    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        (delegate as? Table)?.visible = window != nil
    }
}
#endif

public struct TableCell: ListCell {
    
    let info: CellInfo<PlatformTableCell, CGFloat>
    
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
    
    let prefetch: ((AnyHashable)->Table.Cancel?)?
    let estimatedHeight: (AnyHashable)->CGFloat
    let editor: ((AnyHashable)->Editor)?
    
    #else
    let doubleClick: (AnyHashable)->()
    let menuItems: (AnyHashable)->[NSMenuItem]
    #endif
    
    public let supports: (AnyHashable)->Bool
}

extension PlatformTableView: ListView {
    public typealias Cell = TableCell
    public typealias Delegate = PlatformTableDelegate
    public typealias CellSize = CGFloat
    public typealias ContainerCell = ContainerTableCell
    
    public var scrollView: PlatformScrollView {
        #if os(iOS)
        self
        #else
        enclosingScrollView!
        #endif
    }
}

public class Table: BaseList<PlatformTableView> {
    
    public var useAutomaticHeights = true {
        didSet {
            #if os(iOS)
            view.estimatedRowHeight = useAutomaticHeights ? 150 : 0
            #else
            view.usesAutomaticRowHeights = useAutomaticHeights
            #endif
        }
    }
    
    public var addAnimation: PlatformTableViewAnimation = {
        #if os(iOS)
        .fade
        #else
        .effectFade
        #endif
    }()
    
    public var deleteAnimation: PlatformTableViewAnimation = {
        #if os(iOS)
        .fade
        #else
        .effectFade
        #endif
    }()
    
    #if os(iOS)
    var prefetchTokens: [IndexPath:Cancel] = [:]
    
    public struct Cancel {
        let cancel: ()->()
        
        public init(_ cancel: @escaping ()->()) {
            self.cancel = cancel
        }
    }
    
    public func scrollTo(item: AnyHashable, animated: Bool) {
        if let index = items.firstIndex(of: item) {
            view.scrollToRow(at: IndexPath(row: index, section:0), at: .none, animated: animated)
        }
    }
    #else
    
    public var didScroll: (()->())?
    
    public var deselectedAll: (()->())?
    
    @objc private func doubleClickAction(_ sender: Any) {
        if let item = items[safe: view.clickedRow] {
            cell(item)?.doubleClick(item)
        }
    }
    
    public var selectedItem: AnyHashable? {
        set {
            if let item = newValue, let index = items.firstIndex(of: item) {
                FirstResponderPreserver.performWith(view.window) {
                    view.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                }
            } else {
                view.deselectAll(nil)
            }
        }
        get { items[safe: view.selectedRow] }
    }
    #endif
    
    public required init(listView: PlatformTableView? = nil, emptyStateView: PlatformView) {
        super.init(listView: listView, emptyStateView: emptyStateView)
        delegate.add(self)
        delegate.addConforming([PlatformTableDelegate.self, PlatformTableDataSource.self])
        view.delegate = delegate as? PlatformTableDelegate
        view.dataSource = delegate as? PlatformTableDataSource
        
        #if os(iOS)
        view.tableFooterView = UIView()
        #else
        view.menu = NSMenu()
        view.menu?.delegate = self
        view.wantsLayer = true
        view.target = self
        view.doubleAction = #selector(doubleClickAction(_:))
        view.usesAutomaticRowHeights = true
        
        NotificationCenter.default.publisher(for: NSView.boundsDidChangeNotification, object: view.scrollView.contentView).sink { [weak self] _ in
            self?.didScroll?()
        }.retained(by: self)
        #endif
    }
    
    public override class func createDefaultView() -> PlatformTableView {
        #if os(iOS)
        let table = UITableView(frame: CGRect.zero, style: .plain)
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
        let table = NoEmptyCellsTableView(frame: .zero)
        
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
    
    public override func reloadVisibleCells(excepting: Set<Int> = Set()) {
        func update(cell: PlatformTableCell, index: Int) {
            let item = items[index]
            
            if item as? PlatformView == nil {
                self.cell(item)?.info.fill(item, cell)
            }
        }
        
        #if os(iOS)
        view.visibleCells.forEach {
            if let indexPath = view.indexPath(for: $0), !excepting.contains(indexPath.item) {
                update(cell: $0, index: indexPath.row)
                $0.separatorHidden = indexPath.row == items.count - 1 && view.tableFooterView != nil
            }
        }
        #else
        let rows = view.rows(in: view.visibleRect)
        for i in rows.location..<(rows.location + rows.length) {
            if !excepting.contains(i), let view = view.rowView(atRow: i, makeIfNecessary: false) {
                update(cell: view, index: i)
            }
        }
        #endif
    }
    
    public override func update(_ items: [AnyHashable], animated: Bool, reloadCells: (Set<Int>) -> (), completion: @escaping () -> ()) {
        
        #if os(macOS)
        let preserver = FirstResponderPreserver(window: view.window)
        #else
        view.prefetchDataSource = cells.contains(where: { $0.prefetch != nil }) ? self : nil
        #endif
        
        view.reload(oldData: self.items,
                    newData: items,
                    updateObjects: reloadCells,
                    addAnimation: addAnimation,
                    deleteAnimation: deleteAnimation,
                    animated: animated)
        
        #if os(macOS)
        didScroll?()
        preserver.commit()
        #endif
        
        completion()
    }
    
    deinit {
        #if os(iOS)
        prefetchTokens.values.forEach { $0.cancel() }
        #endif
    }
}
