//
//  FailedBar.swift
//  Ivory
//
//  Created by Ilya Kuznetsov on 28/12/2022.
//

import SwiftUI
import CommonUtils

@available (iOS 15, *)
public struct FailedBar: View {
    
    let fail: LoadingHelper.Fail
    
    public var body: some View {
        VStack {
            Text(fail.error.localizedDescription)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .padding(.all, 15)
                .background(.secondary)
                .cornerRadius(15)
                .padding(.all, 15)
            Spacer()
        }
    }
}
