//
//  LoadingContainer.swift
//

import SwiftUI
import CommonUtils

#if os(iOS)

public protocol FailedViewProtocol: View {
    
    init(fail: LoadingHelper.Fail)
}

public protocol LoadingViewProtocol: View {
    
    init(task: LoadingHelper.TaskWrapper)
}

@available (iOS 15, *)
public struct LoadingContainer<Content: View>: View {
    
    @EnvironmentObject private var alerts: AlertPresenter
    @ObservedObject public var helper: LoadingHelper
    
    private let loadingView: (LoadingHelper.TaskWrapper)-> any LoadingViewProtocol
    private let failedView: (LoadingHelper.Fail)-> any FailedViewProtocol
    private let content: ()->Content
    @State private var nonblockingFail: LoadingHelper.Fail?
    
    public init(_ helper: LoadingHelper,
                loadingView: @escaping (LoadingHelper.TaskWrapper) -> any LoadingViewProtocol = { LoadingView(task: $0) },
                failedView: @escaping (LoadingHelper.Fail) -> any FailedViewProtocol = { FailedView(fail: $0) },
                content: @escaping () -> Content) {
        self.helper = helper
        self.loadingView = loadingView
        self.failedView = failedView
        self.content = content
    }
    
    private var loading: some View {
        let loading = helper.processing.values.first { $0.presentation == .opaque } ??
                        helper.processing.values.first { $0.presentation == .translucent } ??
                        helper.processing.values.first { $0.presentation == .nonblocking }
        
        let animated = loading == nil || loading!.presentation != .opaque
        
        return ZStack {
            if let loading = loading, loading.presentation != .none {
                if loading.presentation == .opaque || loading.presentation == .translucent {
                    loadingView(loading).asAny
                } else {
                    LoadingBar(task: loading).asAny
                }
            }
        }.animation(animated ? .shortEaseOut : .none, value: loading == nil)
    }
    
    public var body: some View {
        content().overlay {
            if let fail = nonblockingFail {
                FailedBar(fail: fail).transition(.slideWithOpacity).onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeIn) { nonblockingFail = nil }
                    }
                }
            }
            if let fail = helper.opaqueFail {
                failedView(fail).asAny
            }
            loading
        }.onReceive(helper.didFail, perform: { fail in
            switch fail.presentation {
            case .translucent, .alertOnFail:
                alerts.show({ Text(fail.error.localizedDescription) }, actions: {
                    Button("OK", action: { })
                    if let retry = fail.retry {
                        Button("Retry", action: retry)
                    }
                })
            case .nonblocking:
                withAnimation(.shortEaseOut) { nonblockingFail = fail }
            default: break
            }
        }).environmentObject(helper)
    }
}

#endif
