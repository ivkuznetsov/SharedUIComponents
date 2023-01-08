//
//  Paging+SwiftUI.swift
//  
//
//  Created by Ilya Kuznetsov on 07/01/2023.
//

import SwiftUI
import Combine

public typealias PagingGridLayout = PagingLayout<Collection, CollectionView>
public typealias PagingListLayout = PagingLayout<Table, PlatformTableView>

public class PagingListViewController<List: BaseList<R>, R>: PlatformViewController {
    
    fileprivate let tracker: ListTracker<List, R>
    
    init(paging: Paging) {
        tracker = ListTracker(list: List(emptyStateView: PlatformView()), paging: paging)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        tracker.list.attachTo(view)
    }
}

public struct PagingLayout<List: BaseList<R>, R>: UIViewControllerRepresentable {
    public typealias UIViewControllerType = PagingListViewController<List, R>
    
    private let paging: Paging
    private let setup: ((List)->())?
    
    public init(_ paging: Paging, setup: ((List)->())? = nil) {
        self.paging = paging
        self.setup = setup
    }
    
    public func makeUIViewController(context: Context) -> UIViewControllerType {
        let vc = UIViewControllerType(paging: paging)
        setup?(vc.tracker.list)
        return vc
    }
    
    public func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
}
