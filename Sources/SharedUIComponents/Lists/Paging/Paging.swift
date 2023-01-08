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
public typealias PagingTable = ListTracker<Table, PlatformTableView>

@MainActor
public class Paging: ObservableObject {
    
    public var performOnRefresh: (()->())? = nil
    
    public var shouldLoadMore: ()->Bool = { true }
    
    public var firstPageCache: (save: ([AnyHashable])->(), load: ()->[AnyHashable])? = nil {
        didSet {
            if let items = firstPageCache?.load() {
                content = Content(items, next: nil)
            }
        }
    }
    
    private var paramenters: (loadPage: (_ offset: Any?) async throws -> Content, loader: LoadingHelper)!
    
    public func set(loadPage: @escaping (_ offset: Any?) async throws -> Content, with loader: LoadingHelper) {
        paramenters = (loadPage, loader)
    }
    
    public enum Direction {
        case bottom
        case top
    }
    
    public var direction = Direction.bottom
    
    public init() {}
    
    public struct Content {
        public let items: [AnyHashable]
        public let next: Any?
        
        public init(_ items: [AnyHashable], next: Any? = nil) {
            self.items = items
            self.next = next
        }
        
        public static var empty: Content { Content([]) }
    }
    
    @Published public var content = Content.empty
    public let state = LoadingState()
    
    private func append(_ content: Content) {
        var array = self.content.items
        var set = Set(array)
        
        let itemsToAdd = direction == .top ? content.items.reversed() : content.items
        
        itemsToAdd.forEach {
            if !set.contains($0) {
                set.insert($0)
                
                if direction == .top {
                    array.insert($0, at: 0)
                } else {
                    array.append($0)
                }
            }
        }
        self.content = Content(array, next: content.next)
    }
    
    public func refresh(showFail: Bool = false) {
        performOnRefresh?()
        
        paramenters.loader.run(content.items.isEmpty ? .opaque : (showFail ? .alertOnFail : .none), id: "feed") { [weak self] _ in
            self?.state.value = .loading
            
            do {
                if let result = try await self?.paramenters.loadPage(nil) {
                    self?.state.value = .stop
                    self?.content = result
                    self?.firstPageCache?.save(result.items)
                }
            } catch {
                self?.state.process(error)
                throw error
            }
        }
    }
    
    fileprivate func loadMoreIfAllowed() {
        guard state.value != .loading, let next = content.next, shouldLoadMore() else { return }
        
        paramenters.loader.run(.none, id: "feed") { [weak self] _ in
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
}

@MainActor
public class ListTracker<List: BaseList<R>, R>: NSObject {
    
    public let paging: Paging
    public let list: List
    public let footer: FooterLoadingView
    
    public init(list: List,
         paging: Paging,
         hasRefreshControl: Bool = true) {
        
        self.list = list
        self.paging = paging
        self.footer = FooterLoadingView(state: paging.state)
        super.init()
        
        footer.retry = { [weak paging] in
            paging?.loadMoreIfAllowed()
        }
        list.delegate.add(self)
        
        #if os(iOS)
        let refreshControl = hasRefreshControl ? RefreshControl() : nil
        refreshControl?.addTarget(self, action: #selector(refreshAction), for: .valueChanged)
        list.view.scrollView.refreshControl = refreshControl

        paging.$content.sink { [weak self] content in
            guard let wSelf = self else { return }
            
            wSelf.list.set(wSelf.itemsWithFooter(content), animated: false)
            
            if content.next != nil {
                DispatchQueue.main.async {
                    self?.checkEndOfList()
                }
            }
        }.retained(by: self)
        
        list.view.scrollView.publisher(for: \.contentOffset).sink { [weak self] _ in
            self?.checkEndOfList()
        }.retained(by: self)
        
        paging.state.$value.sink { [weak self] state in
            if state != .loading {
                self?.endRefreshing()
            }
        }.retained(by: self)
        
        #else
        NotificationCenter.default.publisher(for: NSView.boundsDidChangeNotification).sink { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.checkEndOfList()
            }
        }.retained(by: self)
        #endif
    }
    
    private func checkEndOfList() {
        let footerVisisble = isFooterVisible
        
        if case .failed(_) = paging.state.value, !footerVisisble {
            paging.state.reset()
        }
        if paging.state.value == .stop && footerVisisble {
            paging.loadMoreIfAllowed()
        }
    }
    
    private func itemsWithFooter(_ content: Paging.Content?) -> [AnyHashable] {
        let items = content?.items ?? []
        
        var noRefreshControl = true
        #if os(iOS)
        noRefreshControl = list.view.scrollView.refreshControl == nil
        #endif
        
        if (noRefreshControl && content == nil) || content?.next != nil {
            return items.appending(footer)
        } else {
            return items
        }
    }
    
    private var isFooterVisible: Bool {
        guard paging.content.next != nil else { return false }
        
        let scrollView = list.view.scrollView
        let frame = scrollView.convert(footer.bounds, from: footer)
        
        var superview = footer.superview
        while superview != scrollView {
            if superview?.isHidden == true || superview == nil {
                return false
            } else {
                superview = superview?.superview
            }
        }
        
        return (scrollView.contentSize.height > scrollView.height ||
                scrollView.contentSize.width > scrollView.width ||
                scrollView.contentSize.height > 0) &&
        scrollView.bounds.intersects(frame)
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
            paging.refresh(showFail: true)
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
