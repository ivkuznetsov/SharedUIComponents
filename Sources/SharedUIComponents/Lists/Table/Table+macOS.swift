//
//  Table+macOS.swift
//

#if os(macOS)
import AppKit

extension Table: NSTableViewDataSource, NSTableViewDelegate {
    
    public func addCell<T: PlatformTableCell, R: Hashable>(for itemType: R.Type,
                                                           type: T.Type,
                                                           fill: @escaping (R, T)->(),
                                                           source: CellSource = .nib,
                                                           height: @escaping (R)->CGFloat = { _ in -1 },
                                                           action: ((R)->())? = nil,
                                                           doubleClick: ((R)->())? = nil,
                                                           menuItems: @escaping (AnyHashable)->[NSMenuItem] = { _ in [] }) {
        set(cell: .init(info: .init(itemType: itemType,
                                    type: type,
                                    fill: { fill($0 as! R, $1 as! T) },
                                    source: source,
                                    size: { height($0 as! R) },
                                    action: { action?($0 as! R) }),
                        doubleClick: { doubleClick?($0 as! R) },
                        menuItems: { menuItems($0 as! R) },
                        supports: { $0 is R }))
    }
    
    public func numberOfRows(in tableView: NSTableView) -> Int { items.count }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? { nil }
    
    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let item = items[row]
        
        if let view = item as? NSView {
            let cell = self.view.createCell(for: ContainerTableCell.self, source: .code(reuseId: "\(view.hash)"))
            cell.attach(viewToAttach: view, type: .constraints)
            setupViewContainer?(cell)
            return cell
        } else if let createCell = cell(item)?.info {
            let cell = view.createCell(for: createCell.type, source: .nib)
            createCell.fill(item, cell)
            return cell
        }
        return nil
    }
    
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let item = items[row]
        var height = cachedSize(for: item)
        
        if height == nil {
            height = cell(item)?.info.size(item)
            cache(size: height, for: item)
        }
        return height ?? -1
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        let selected = view.selectedRowIndexes
        
        if selected.isEmpty {
            deselectedAll?()
        } else {
            selected.forEach {
                view.deselectRow($0)
                let item = items[$0]
                cell(item)?.info.action(item)
            }
        }
    }
}

extension Table: NSMenuDelegate {
    
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let item = items[safe: view.clickedRow] {
            cell(item)?.menuItems(item).forEach { menu.addItem($0) }
        }
    }
}
#endif
