//
//  File.swift
//  
//
//  Created by Ilya Kuznetsov on 07/01/2023.
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import Combine
import CommonUtils
import SwiftUI

#if os(iOS)
class RefreshControl: UIRefreshControl {
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        if window != nil && isRefreshing, let scrollView = superview as? UIScrollView {
            let offset = scrollView.contentOffset
            UIView.performWithoutAnimation { endRefreshing() }
            beginRefreshing()
            scrollView.contentOffset = offset
        }
    }
}
#endif

public typealias PagingCollection = ListTracker<Collection, CollectionView>
public typealias TableCollection = ListTracker<Table, PlatformTableView>

fileprivate let pagingLoadingSectionId = "pagingLoadingSectionId"

public extension Snapshot {
    
    mutating func addLoading() {
        addViewSectionId(pagingLoadingSectionId)
    }
}

public class Paging<Item: Hashable>: BasePaging { }

public struct PagingContent {
    public let items: [AnyHashable]
    public let next: AnyHashable?
    
    public init(_ items: [AnyHashable], next: AnyHashable? = nil) {
        self.items = items
        self.next = next
    }
    
    public static var empty: PagingContent { PagingContent([]) }
    
    func isEqual(_ content: PagingContent) async -> Bool {
        if items.count != content.items.count || next != content.next {
            return false
        }
        return items == content.items
    }
}

@MainActor
public class BasePaging: ObservableObject {
    
    public var performOnRefresh: (()->())? = nil
    
    public var shouldLoadMore: ()->Bool = { true }
    
    public var firstPageCache: (save: ([AnyHashable])->(), load: ()->[AnyHashable])? = nil {
        didSet {
            if let items = firstPageCache?.load() {
                content = PagingContent(items, next: nil)
            }
        }
    }
    
    private var paramenters: (loadPage: (_ offset: AnyHashable?) async throws -> PagingContent, loader: LoadingHelper)!
    
    public func set(loadPage: @escaping (_ offset: AnyHashable?) async throws -> PagingContent, with loader: LoadingHelper) {
        paramenters = (loadPage, loader)
    }
    
    public enum Direction {
        case bottom
        case top
    }
    
    private let direction: Direction
    private let initialLoading: LoadingHelper.Presentation
    private let feedId = UUID().uuidString
    
    public init(direction: Direction = .bottom, initialLoading: LoadingHelper.Presentation = .opaque) {
        self.direction = direction
        self.initialLoading = initialLoading
    }
    
    @Published public var content = PagingContent.empty
    public let state = LoadingState()
    
    private func append(_ content: PagingContent) {
        let itemsToAdd = direction == .top ? content.items.reversed() : content.items
        var array = direction == .top ? self.content.items.reversed() : self.content.items
        var set = Set(array)
        var allItemsAreTheSame = true // backend returned the same items for the next page, prevent for infinit loading
        
        itemsToAdd.forEach {
            if !set.contains($0) {
                set.insert($0)
                array.append($0)
                allItemsAreTheSame = false
            }
        }
        self.content = PagingContent(direction == .top ? array.reversed() : array, next: allItemsAreTheSame ? nil : content.next)
    }
    
    public func initalRefresh() {
        if state.value != .loading && content.items.isEmpty {
            refresh()
        }
    }
    
    public func refresh(userInitiated: Bool = false) {
        performOnRefresh?()
        
        paramenters.loader.run(userInitiated ? .alertOnFail : (content.items.isEmpty ? initialLoading : .none), id: feedId) { [weak self] _ in
            self?.state.value = .loading
            
            do {
                if let result = try await self?.paramenters.loadPage(nil),
                   let equal = await self?.content.isEqual(result) {
                    
                    self?.state.value = .stop
                    if !equal {
                        self?.content = result
                        self?.firstPageCache?.save(result.items)
                    }
                }
            } catch {
                self?.state.process(error)
                throw error
            }
        }
    }
    
    public func loadMore() {
        guard let next = content.next else { return }
        
        paramenters.loader.run(.none, id: feedId) { [weak self] _ in
            self?.state.value = .loading
            
            do {
                if let result = try await self?.paramenters.loadPage(next) {
                    self?.append(result)
                    self?.state.value = .stop
                }
            } catch {
                self?.state.process(error)
                throw error
            }
        }
    }
    
    fileprivate func loadMoreIfAllowed() {
        guard state.value != .loading, shouldLoadMore() else { return }
        
        loadMore()
    }
}

@MainActor
public final class ListTracker<List: ListContainer<View>, View>: NSObject {
    
    public let list: List
    public let loadMoreView = FooterLoadingView()
    
    private var observers: [AnyCancellable] = []
    private(set) var paging: BasePaging?
    
    public func set<T: Hashable>(paging: Paging<T>?, data: (([T])->Snapshot<View>)? = nil) {
        set(paging: paging, data: data == nil ? nil : { data!($0 as! [T]) })
    }
    
    public func set(paging: BasePaging?, data: (([AnyHashable])->Snapshot<View>)? = nil) {
        if self.paging === paging { return }
        self.paging = paging
        
        loadMoreView.observe(paging?.state)
        
        observers = []
        paging?.$content.sink { [weak self] content in
            DispatchQueue.main.async {
                if let data = data {
                    self?.set(data(content.items))
                }
            }
        }.store(in: &observers)
        
        #if os(iOS)
        paging?.state.$value.sink { [weak self] state in
            if state != .loading {
                self?.endRefreshing()
            }
        }.store(in: &observers)
        #endif
    }
    
    public init(list: List, hasRefreshControl: Bool = true) {
        self.list = list
        super.init()
        list.delegate.add(self)
        
        loadMoreView.retry = { [weak self] in
            guard let wSelf = self, let paging = wSelf.paging else { return }
            if paging.content.next != nil {
                paging.loadMoreIfAllowed()
            } else {
                paging.refresh(userInitiated: true)
            }
        }
        
        #if os(iOS)
        let refreshControl = hasRefreshControl ? RefreshControl() : nil
        refreshControl?.addTarget(self, action: #selector(refreshAction), for: .valueChanged)
        list.view.scrollView.refreshControl = refreshControl
        list.view.scrollView.publisher(for: \.contentOffset).sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.onScroll()
            }
        }.retained(by: self)
        #else
        NotificationCenter.default.publisher(for: NSView.boundsDidChangeNotification).sink { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.onScroll()
            }
        }.retained(by: self)
        #endif
    }
    
    private func onScroll() {
        guard let paging = paging, paging.content.next != nil else { return }
        
        let allowLoad = isFooterVisible == true
        
        if case .failed(_) = paging.state.value, !allowLoad {
            paging.state.reset()
        }
        if paging.state.value == .stop && allowLoad {
            paging.loadMoreIfAllowed()
        }
    }
    
    public func set(_ snapshot: Snapshot<View>, animated: Bool = false) {
        var result = snapshot
        
        if let paging = paging, snapshot.data.sectionIdentifiers.contains(pagingLoadingSectionId) {
            var noRefreshControl = true
            #if os(iOS)
            noRefreshControl = list.view.scrollView.refreshControl == nil
            #endif
            
            if (noRefreshControl && paging.content.items.isEmpty) || paging.content.next != nil {
                result.add(loadMoreView, sectionId: pagingLoadingSectionId)
            }
        }
        
        Task {
            await list.set(result, animated: animated)
            await MainActor.run {
                onScroll()
            }
        }
    }
    
    private var isFooterVisible: Bool {
        let scrollView = list.view.scrollView
        
        var superview = loadMoreView.superview
        while superview != scrollView {
            if superview?.isHidden == true || superview == nil {
                return false
            } else {
                superview = superview?.superview
            }
        }
        
        let frame = scrollView.convert(loadMoreView.bounds, from: loadMoreView)
        return scrollView.contentSize.height > 0 && scrollView.bounds.intersects(frame)
    }
    
    #if os(iOS)
    private var performedEndRefreshing = false
    private var performedRefresh = false

    @objc private func refreshAction() {
        performedRefresh = true
    }

    @objc func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        endDecelerating()
        list.delegate.without(self) {
            (list.delegate as? UIScrollViewDelegate)?.scrollViewDidEndDecelerating?(scrollView)
        }
    }

    @objc func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { endDecelerating() }
        list.delegate.without(self) {
            (list.delegate as? UIScrollViewDelegate)?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
        }
    }

    func endDecelerating() {
        let scrollView = list.view.scrollView
        if performedEndRefreshing && !scrollView.isDecelerating && !scrollView.isDragging {
            performedEndRefreshing = false
            DispatchQueue.main.async { [weak scrollView] in
                scrollView?.refreshControl?.endRefreshing()
            }
        }
        if performedRefresh {
            performedRefresh = false
            paging?.refresh(userInitiated: true)
        }
    }
    
    private func endRefreshing() {
        let scrollView = list.view.scrollView
        guard let refreshControl = scrollView.refreshControl else { return }
        
        if scrollView.isDecelerating || scrollView.isDragging {
            performedEndRefreshing = true
        } else if scrollView.window != nil && refreshControl.isRefreshing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                refreshControl.endRefreshing()
            })
        } else {
            refreshControl.endRefreshing()
        }
    }
    #endif
}
