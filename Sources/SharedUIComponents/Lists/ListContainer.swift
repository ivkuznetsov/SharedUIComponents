//
//  BaseList.swift
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import CommonUtils

#if os(iOS)
public struct ViewContainer: Hashable {
    let id: String
    let reuseId: String
    let configuration: UIContentConfiguration
    
    init<Content: View>(id: String, view: Content) {
        self.id = id
        self.reuseId = String(describing: type(of: view))
        if #available(iOS 16, *) {
            configuration = UIHostingConfiguration { view }.margins(.all, 0)
        } else {
            configuration = UIHostingConfigurationBackport { view.ignoresSafeArea() }.margins(.all, 0)
        }
    }
    
    public static func == (lhs: ViewContainer, rhs: ViewContainer) -> Bool { lhs.hashValue == rhs.hashValue }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public extension View {
    func inContainer(id: String? = nil) -> ViewContainer {
        let id = String(describing: type(of: self)) + (id ?? "")
        
        return ViewContainer(id: id, view: self.id(id))
    }
}
#endif

public protocol ContainerCell: WithConfiguration {
    func attach(viewToAttach: PlatformView)
}

public enum CellSource {
    case nib
    case code(reuseId: String?)
}

public protocol WithConfiguration: AnyObject {
#if os(iOS)
    var contentConfiguration: UIContentConfiguration? { get set }
#endif
    
    var view: PlatformView { get }
}

public protocol DataSource {
    func snapshot() -> DataSourceSnapshot
    func apply(_ snapshot: DataSourceSnapshot, animated: Bool) async
}

public protocol ListView: PlatformView {
    associatedtype Cell: WithConfiguration
    associatedtype CellAdditions
    associatedtype Content: DataSource
    associatedtype Container: ContainerCell
    
    var scrollView: PlatformScrollView { get }
    
    func enumerateVisibleCells(_ action: (IndexPath, Cell)->())
}

public struct PrefetchCancel {
    let cancel: ()->()

    public init(_ cancel: @escaping ()->()) {
        self.cancel = cancel
    }
}

@MainActor
public class ListContainer<View: ListView>: NSObject {
    
    public var showNoData: (DataSourceSnapshot) -> Bool = { $0.numberOfItems == 0 }
    var dataSource: View.Content!
    
    var oldSnapshot: Snapshot<View>?
    public private(set) var snapshot = Snapshot<View>()
    public let view: View
    public let emptyState = PlatformView()
    public let delegate = DelegateForwarder()
    
    #if os(iOS)
    private var prefetchTokens: [IndexPath:PrefetchCancel] = [:]
    
    func prefetch(_ indexPaths: [IndexPath]) {
        indexPaths.forEach {
            if let info = snapshot.info($0),
               let cancel = info.section.features.prefetch?(info.item) {
                prefetchTokens[$0] = cancel
            }
        }
    }
    
    func cancelPrefetch(_ indexPaths: [IndexPath]) {
        indexPaths.forEach {
            prefetchTokens[$0]?.cancel()
            prefetchTokens[$0] = nil
        }
    }
    
    #endif
    required public init(listView: View? = nil) { fatalError("override") }
    
    init(listView: View) {
        self.view = listView
        super.init()
        
        #if os(macOS)
     /*   let recognizer = NSClickGestureRecognizer(target: self, action: #selector(doubleClickAction(_:)))
        recognizer.numberOfClicksRequired = 2
        recognizer.delaysPrimaryMouseButtonEvents = false
        view.addGestureRecognizer(recognizer) */
        #endif
    }
    
    #if os(iOS)
    
    #else
   /* @objc func doubleClickAction(_ sender: NSClickGestureRecognizer) {
        let location = sender.location(in: view)
        if let indexPath = view.indexPathForItem(at: location) {
            let item = dataSource.items[indexPath.item]
            cell(item)?.doubleClick(item)
        }
    } */
    #endif
    
    private let serialUpdate = SerialTasks()
    
    public func set(_ snapshot: Snapshot<View>, animated: Bool = false) {
        Task { await set(snapshot, animated: animated) }
    }
    
    private func update(snapshot: Snapshot<View>) {
        oldSnapshot = self.snapshot
        self.snapshot = snapshot
    }
    
    public func set(_ snapshot: Snapshot<View>, animated: Bool = false) async {
        try? await serialUpdate.run { @MainActor [oldSnapshot = self.snapshot] in
            let animatedResult = animated && oldSnapshot.data.numberOfItems > 0 && snapshot.data.numberOfItems > 0
            self.update(snapshot: snapshot)
            await self.dataSource.apply(snapshot.data, animated: animatedResult)
            
            if self.showNoData(snapshot.data) {
                self.view.attach(self.emptyState, type: .safeArea)
            } else {
                self.emptyState.removeFromSuperview()
            }
        }
    }
    
    public func reloadVisibleCells() {
        view.enumerateVisibleCells { indexPath, cell in
            if let info = snapshot.info(indexPath), info.item as? PlatformView == nil {
                info.section.creation.fill(info.item, cell.view)
            }
        }
    }
    
    public func attachTo(_ containerView: PlatformView) {
        containerView.attach(view.scrollView)
    }
    
    public func item(_ indexPath: IndexPath) -> AnyHashable? {
        let snapshot = dataSource.snapshot()
        if let section = snapshot.sectionIdentifiers[safe: indexPath.section] {
            return snapshot.itemIdentifiers(inSection: section)[safe: indexPath.item]
        }
        return nil
    }
    
    deinit {
        #if os(iOS)
        prefetchTokens.values.forEach { $0.cancel() }
        #endif
    }
}
