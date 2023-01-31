//
//  Common.swift
//

import Foundation

#if os(iOS)
import UIKit

public typealias PlatformView = UIView
public typealias PlatformViewController = UIViewController
public typealias PlatformButton = UIButton
public typealias PlatformTableView = UITableView
public typealias PlatformTableCell = UITableViewCell
public typealias PlatformCollectionView = UICollectionView
public typealias PlatformCollectionCell = UICollectionViewCell
public typealias PlatformScrollView = UIScrollView
public typealias PlatformTableDataSource = UITableViewDiffableDataSource<String, AnyHashable>
public typealias PlatformTableDelegate = UITableViewDelegate
public typealias PlatformCollectionDataSource = UICollectionViewDiffableDataSource<String, AnyHashable>
public typealias PlatformCollectionDelegate = UICollectionViewDelegate
public typealias PlatformCollectionLayout = UICollectionViewCompositionalLayout

protocol PrefetchCollectionProtocol: UICollectionViewDataSourcePrefetching { }
protocol PrefetchTableProtocol: UITableViewDataSourcePrefetching { }

#else
import AppKit

public typealias PlatformView = NSView
public typealias PlatformViewController = NSViewController
public typealias PlatformButton = NSButton
public typealias PlatformTableView = NSTableView
public typealias PlatformTableCell = NSTableRowView
public typealias PlatformCollectionView = NSCollectionView
public typealias PlatformCollectionCell = NSCollectionViewItem
public typealias PlatformScrollView = NSScrollView
public typealias PlatformTableDataSource = NSTableViewDiffableDataSource<String, AnyHashable>
public typealias PlatformTableDelegate = NSTableViewDelegate
public typealias PlatformCollectionDataSource = NSCollectionViewDiffableDataSource<String, AnyHashable>
public typealias PlatformCollectionDelegate = NSCollectionViewDelegate
public typealias PlatformCollectionLayout = NSCollectionViewCompositionalLayout

protocol PrefetchCollectionProtocol { }
protocol PrefetchTableProtocol { }

#endif
