//
//  FailedView.swift
//  Ivory
//
//  Created by Ilya Kuznetsov on 28/12/2022.
//

import SwiftUI
import CommonUtils

#if os(iOS)

@available (iOS 15, *)
public struct FailedView: FailedViewProtocol {
    
    private let fail: LoadingHelper.Fail
    private let backgroundColor: Color
    
    public init(fail: LoadingHelper.Fail, backgroundColor: Color) {
        self.fail = fail
        self.backgroundColor = backgroundColor
    }
    
    public init(fail: LoadingHelper.Fail) {
        self.init(fail: fail, backgroundColor: Color(.systemBackground))
    }
    
    public var body: some View {
        backgroundColor.ignoresSafeArea()
        VStack(spacing: 0) {
            Text(fail.error.localizedDescription)
                .font(.system(size: 14))
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.all, 30)
                .frame(maxWidth: 400)
            
            if let retry = fail.retry {
                Button("Retry", action: retry)
            }
        }
    }
}

#endif
