//
//  Collection+iOS.swift
//  
//
//  Created by Ilya Kuznetsov on 31/12/2022.
//

#if os(iOS)
import UIKit

extension Collection: UICollectionViewDataSource {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = items[indexPath.item]
        
        if let view = item as? UIView {
            let cell = self.view.createCell(for: ContainerCollectionItem.self, source: .code(reuseId: "\(view.hash)"), at: indexPath)
            cell.attach(view)
            setupViewContainer?(cell)
            return cell
        } else {
            guard let createCell = self.cell(item)?.info else {
                fatalError("Please specify cell for \(item)")
            }
            let cell = view.createCell(for: createCell.type, source: createCell.source, at: indexPath)
            createCell.fill(item, cell)
            return cell
        }
    }
}

extension Collection: UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let item = items[indexPath.row]
        cell(item)?.info.action(item)
    }
}

extension Collection: UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let item = items[indexPath.item]
        
        if let view = item as? UIView {
            
            if view.superview == nil { // perfrom initial trait collection set
                collectionView.addSubview(view)
                view.removeFromSuperview()
            }
            
            let insets = self.view.flowLayout?.sectionInset
            let defaultWidth = collectionView.frame.size.width - (insets?.left ?? 0) - (insets?.right ?? 0)
            
            let targetView = view.superview ?? view
            
            var defaultSize = targetView.systemLayoutSizeFitting(CGSize(width: defaultWidth, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: UILayoutPriority(rawValue: 1000), verticalFittingPriority: UILayoutPriority(rawValue: 1))
            defaultSize.width = defaultWidth
            
            let size = cell(item)?.info.size(item)
            
            if let size = size, size != .zero {
                return CGSize(width: floor(size.width), height: ceil(size.height))
            }
            
            var frame = view.frame
            frame.size.width = defaultWidth
            view.frame = frame
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            let height = view.systemLayoutSizeFitting(CGSize(width: defaultWidth,
                                                             height: UIView.layoutFittingCompressedSize.height),
                                                      withHorizontalFittingPriority: UILayoutPriority(rawValue: 1000),
                                                      verticalFittingPriority: UILayoutPriority(rawValue: 1)).height
            
            return CGSize(width: floor(frame.size.width), height: ceil(height))
        } else {
            var size = cachedSize(for: item)
            
            if size == nil {
                size = cell(item)?.info.size(item)
                cache(size: size, for: item)
            }
            return size ?? .zero
        }
    }
}
#endif
