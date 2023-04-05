//
//  Paging+SwiftUI.swift
//  
//
//  Created by Ilya Kuznetsov on 07/01/2023.
//


#if os(iOS)
import SwiftUI
import Combine

public typealias PagingGrid = PagingLayout<Collection, CollectionView>
public typealias PagingList = PagingLayout<Table, PlatformTableView>

public final class PagingListViewController<List: ListContainer<ListView>, ListView>: ListViewController<List, ListView> {
    
    fileprivate var tracker: ListTracker<List, ListView>!
    
    init(refreshControl: Bool) {
        super.init(nibName: nil, bundle: nil)
        tracker = ListTracker(list: list, hasRefreshControl: refreshControl)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
public struct PagingLayout<List: ListContainer<ListView>, ListView>: UIViewControllerRepresentable {
    public typealias UIViewControllerType = PagingListViewController<List, ListView>
    
    private var snapshot = Snapshot<ListView>()
    private let refreshControl: Bool
    private let emptyState: any View
    private let updatePaging: (ListTracker<List, ListView>)->()
    private let setup: ((ListTracker<List, ListView>)->())?
    
    public init<T>(typed paging: Paging<T>?,
                refreshControl: Bool = true,
                emptyState: any View = EmptyView(),
                data: @escaping (inout Snapshot<ListView>, [T])->(),
                setup: ((ListTracker<List, ListView>)->())? = nil) {
        self.init(paging as BasePaging?,
                  refreshControl: refreshControl,
                  emptyState: emptyState,
                  data: { data(&$0, $1 as! [T]) },
                  setup: setup)
    }
    
    public init(_ paging: BasePaging?,
                refreshControl: Bool = true,
                emptyState: any View = EmptyView(),
                data: @escaping (inout Snapshot<ListView>, [AnyHashable])->(),
                setup: ((ListTracker<List, ListView>)->())? = nil) {
        self.updatePaging = { $0.set(paging: paging) }
        self.emptyState = emptyState
        data(&snapshot, paging?.content.items ?? [])
        self.refreshControl = refreshControl
        self.setup = setup
    }
    
    public func makeUIViewController(context: Context) -> UIViewControllerType {
        let vc = UIViewControllerType(refreshControl: refreshControl)
        setup?(vc.tracker)
        return vc
    }
    
    public func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        let oldPaging = uiViewController.tracker.paging
        updatePaging(uiViewController.tracker)
        uiViewController.emptyState.rootView = emptyState.asAny
        uiViewController.tracker.set(snapshot, animated: oldPaging === uiViewController.tracker.paging)
    }
}
#endif
