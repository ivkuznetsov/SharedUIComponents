//
//  LoadingView.swift
//

import SwiftUI
import CommonUtils

@available (iOS 15, *)
fileprivate extension ProgressView {
    
    var styled: some View { progressViewStyle(.circular).controlSize(.large).tint(.gray) }
}

@available (iOS 15, *)
public struct LoadingView: LoadingViewProtocol {
    
    private struct CircularProgressView: View {
        
        let progress: Double
        
        var body: some View {
            ZStack {
                Circle().stroke(Color(.label).opacity(0.1), style: .init(lineWidth: 3))
                Circle().trim(from: 0, to: progress)
                    .rotation(.degrees(-90))
                    .stroke(Color(.label), style: .init(lineWidth: 3, lineCap: .round))
            }.frame(width: 50, height: 50)
                .animation(.shortEaseOut, value: progress)
        }
    }
    
    @ObservedObject private var task: LoadingHelper.TaskWrapper
    private let backgroundColor: Color
    
    public init(task: LoadingHelper.TaskWrapper, backgroundColor: Color) {
        self.task = task
        self.backgroundColor = backgroundColor
    }
    
    public init(task: LoadingHelper.TaskWrapper) {
        self.init(task: task, backgroundColor: Color(.systemBackground))
    }
    
    public var body: some View {
        backgroundColor.opacity(task.presentation == .opaque ? 1 : 0.7).ignoresSafeArea()
        
        if task.progress > 0 {
            CircularProgressView(progress: task.progress)
        } else {
            ProgressView().styled
        }
    }
}
