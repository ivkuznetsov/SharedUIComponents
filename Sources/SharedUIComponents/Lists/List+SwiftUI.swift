//
//  List+SwiftUI.swift
//  
//
//  Created by Ilya Kuznetsov on 31/12/2022.
//

import SwiftUI
import Combine

#if os(iOS)
public typealias GridLayout = Layout<Collection, CollectionView>

public typealias ListLayout = Layout<Table, PlatformTableView>

public class ListViewController<List: BaseList<R>, R>: PlatformViewController {
    
    fileprivate let list = List(emptyStateView: PlatformView())
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        list.attachTo(view)
    }
}

public struct Layout<List: BaseList<R>, R>: UIViewControllerRepresentable {
    public typealias UIViewControllerType = ListViewController<List, R>
    
    private let items: [AnyHashable]
    private let setup: ((List)->())?
    
    public init(_ items: [AnyHashable], setup: ((List)->())? = nil) {
        self.items = items
        self.setup = setup
    }
    
    public func makeUIViewController(context: Context) -> UIViewControllerType {
        let vc = UIViewControllerType()
        setup?(vc.list)
        return vc
    }
    
    public func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        uiViewController.list.set(items, animated: true)
    }
}

class DataCollectionCell: PlatformCollectionCell { }
class DataTableCell: BaseTableViewCell { }

@available(iOS 16, *)
extension Collection {
    
    public func setCell<R: Hashable>(for item: R.Type,
                                     fill: @escaping (R)-> any View,
                                     size: @escaping (R)->CGSize) {
        addCell(for: item,
                type: DataCollectionCell.self,
                fill: { item, cell in
            cell.contentConfiguration = UIHostingConfiguration { fill(item).asAny }
        },
                source: .code(reuseId: String(describing: item)),
                size: size,
                action: nil)
    }
}

@available(iOS 16, *)
extension Table {
    
    public func setCell<R: Hashable>(for item: R.Type,
                                     fill: @escaping (R)-> any View,
                                     estimatedHeight: @escaping (R)->CGFloat = { _ in 150 },
                                     height: @escaping (R)-> CGFloat = { _ in -1 },
                                     editor: ((R)->TableCell.Editor)? = nil,
                                     prefetch: ((R)->Table.Cancel)? = nil) {
        addCell(for: item,
                type: DataTableCell.self,
                fill: { item, cell in
            cell.contentConfiguration = UIHostingConfiguration { fill(item).asAny }
        }, source: .code(reuseId: String(describing: item)),
                estimatedHeight: estimatedHeight,
                height: height,
                action: nil,
                editor: editor,
                prefetch: prefetch)
    }
}

#endif
