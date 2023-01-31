//
//  List+SwiftUI.swift
//  
//
//  Created by Ilya Kuznetsov on 31/12/2022.
//

#if os(iOS)
import UIKit
import SwiftUI
import Combine

public typealias GridLayout = Layout<Collection, CollectionView>

public typealias ListLayout = Layout<Table, PlatformTableView>

public class ListViewController<List: ListContainer<R>, R>: PlatformViewController {
    
    let list = List()
    let emptyState = UIHostingController(rootView: AnyView(EmptyView()))
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        list.attachTo(view)
        list.emptyState.attach(emptyState.view)
    }
}

@MainActor
public struct Layout<List: ListContainer<ListView>, ListView>: UIViewControllerRepresentable {
    public typealias UIViewControllerType = ListViewController<List, ListView>
    
    private let snapshot: Snapshot<ListView>
    private let setup: ((List)->())?
    private let emptyState: any View
    
    public init(_ views: [ViewContainer], setup: ((List)->())? = nil) {
        self.init({ $0.addSection(views) }, setup: setup)
    }
    
    public init(emptyState: any View = EmptyView(), _ data: (inout Snapshot<ListView>)->(), setup: ((List)->())? = nil) {
        var snapshot = Snapshot<ListView>()
        data(&snapshot)
        self.snapshot = snapshot
        self.setup = setup
        self.emptyState = emptyState
    }
    
    public func makeUIViewController(context: Context) -> UIViewControllerType {
        UIViewControllerType()
    }
    
    public func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        uiViewController.emptyState.rootView = emptyState.asAny
        uiViewController.list.set(snapshot, animated: true)
    }
}
#endif
