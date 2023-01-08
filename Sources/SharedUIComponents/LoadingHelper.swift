//
//  LoadingHelper.swift
//

import Foundation
import Combine
import CommonUtils

@MainActor
public class LoadingHelper: ObservableObject {

    public init() { }
    
    public enum Presentation {
        
        // fullscreen opaque overlay loading with fullscreen opaque error
        case opaque
        
        // fullscreen semitransparent overlay loading with alert error
        #if os(iOS)
        case translucent
        #else
        case modal(details: String, cancellable: Bool)
        #endif
        
        // doesn't show loading, error is shown in alert
        case alertOnFail
        
        // shows loading bar at the top of the screen without blocking the content, error is shown as label at the top for couple of seconds
        case nonblocking
        
        case none
    }
    
    public struct Fail {
        public let error: Error
        public let retry: (()->())?
        public let presentation: Presentation
    }
    
    private let failPublisher = PassthroughSubject<Fail, Never>()
    public var didFail: AnyPublisher<Fail, Never> { failPublisher.eraseToAnyPublisher() }
    
    @Published public private(set) var processing: [String:TaskWrapper] = [:]
    
    public enum Options: Hashable {
        case showsProgress
    }
    
    public class TaskWrapper: Hashable {
        let id: String
        public let presentation: Presentation
        let cancel: ()->()
        
        init(id: String, presentation: Presentation, cancel: @escaping () -> Void) {
            self.id = id
            self.presentation = presentation
            self.cancel = cancel
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        public static func == (lhs: LoadingHelper.TaskWrapper, rhs: LoadingHelper.TaskWrapper) -> Bool { lhs.hashValue == rhs.hashValue }
        
        deinit { cancel() }
    }
    
    public func run(_ presentation: Presentation, id: String? = nil, _ action: @escaping () async throws -> ()) {
        let id = id ?? UUID().uuidString
        
        let task = Task { [weak self] in
            do {
                try await action()
            } catch {
                if !error.isCancelled {
                    self?.failPublisher.send(Fail(error: error,
                                                  retry: { _ = self?.run(presentation, id: id, action) },
                                                  presentation: presentation))
                }
            }
            self?.processing[id] = nil
        }
        
        let wrapper = TaskWrapper(id: id, presentation: presentation) {
            task.cancel()
        }
        
        processing[id]?.cancel()
        processing[id] = wrapper
        
        if task.isCancelled {
            processing[id] = nil
        }
    }
    
    public func cancelOperations() {
        processing.forEach { $0.value.cancel() }
    }
}
