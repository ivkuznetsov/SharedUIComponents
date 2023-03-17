//
//  File.swift
//  
//
//  Created by Ilya Kuznetsov on 12/01/2023.
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

public extension NSCollectionLayoutItem {
    
    static var item: NSCollectionLayoutItem {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                             heightDimension: .fractionalHeight(1.0))
        return NSCollectionLayoutItem(layoutSize: itemSize)
    }
}

public extension NSCollectionLayoutSection {
    
    #if os(iOS)
    static func list(_ environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        .list(using: .init(appearance: .plain), layoutEnvironment: environment)
    }
    #endif
    
    static func grid(height: CGFloat? = nil,
                     _ environment: NSCollectionLayoutEnvironment,
                     spacing: NSDirectionalEdgeInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 0)) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: height != nil ? .absolute(height!) : .estimated(150))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(150))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = spacing
        return section
    }
    
    static func grid(maxWidth: CGFloat, height: (_ width: CGFloat)->CGFloat, spacing: CGFloat = 15, environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        
        let fullWidth = environment.container.effectiveContentSize.width - spacing * 2
        let count = ceil(fullWidth / maxWidth)
        let resultWidth = floor((fullWidth - spacing * (count - 1)) / count)
        let resultHeight = ceil(height(resultWidth))
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(resultWidth),
                                             heightDimension: .absolute(resultHeight))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(fullWidth),
                                               heightDimension: .absolute(resultHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.interItemSpacing = .fixed(spacing)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = .init(top: spacing, leading: spacing, bottom: spacing, trailing: spacing)

        return section
    }
    
    static func horizontalGrid(size: CGSize, spacing: CGFloat = 15) -> NSCollectionLayoutSection {
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(size.width),
                                               heightDimension: .absolute(size.width))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [.item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = spacing
        section.contentInsets = .init(top: 0, leading: spacing, bottom: 0, trailing: spacing)

        return section
    }
}
