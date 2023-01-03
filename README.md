# SharedUIComponents
> Crossplatform macOS/iOS UI helpers

Several classes and extensions simplifying implementation of UI in iOS and macOS apps.

## Collection and Table

CollectionView and TableView model driving wrappers. The wrappers support empty state view and animated reload, both have similar interface, and crossplatofrm supprt between iOS and macOS.

Let's make model and collection cell:

```swift
struct Model: Hashable {
    let text: String
}

class ModelCell: UICollectionViewCell {
    @IBOutlet private var title: UILabel!
    
    var model: Model! {
        didSet {
            title.text = model.text
        }
    }
}
```

Create a collection wrapper:

```swift
let collection = Collection()
```

Then you need to attach it to the view and describe the cells used for each model type used:

```swift
collection.attachTo(view)

collection.setCell(for: Model.self,
                   type: ModelCell.self,
                   fill: { $1.model = $0 },
                   size: { _ in CGSize(width: 150, height: 150) },
                   action: {
    print("\($0.text) selected")
})
```

By performing set() function you can update the content. When animated == true the wrapper calculated a diff with changes and performs adding, deleting and moving of the cells.

```swift
let arrayOfModels: [Model]
        
collection.set(arrayOfModels, animated: true)
```

You can mix model types in the array. Also you can put there an ordinary View. In this case you don't need to supply a description, the wrapper will use autolayout to calculate the size of the cell containing the View.

```swift
var mixedArray: [AnyHashable] = []

mixedArray += modelsArray as [AnyHashable]
mixedArray.append(someView)
mixedArray += models2Array as [AnyHashable]

collection.set(mixedArray, animated: true)
```

You still can implement TableVideDelegate / CollectionViewDelegate functions in your ViewController. The wrappers forward the ones that has not been used by the wrappers themself.

```swift
collection.delegate.add(self)
```

## GridLayout and TableLayot

A bridge to SwiftUI for the Collection and Table

```swift
GridLayout(arrayOfModels) {
    $0.setCell(for: Model.self,
               fill: {
        ModelView(model: $0)
    }, size: {
        _ in CGSize(width: 150, height: 150)
    })
}
```

## PagingCollection and PagingTable

A composition of Collection and Table with the PagingLoader. These have everything you might need to make a list with pagination.

Let's make a PagingCollection. You need to add you model description as before:

```swift
let collection = PagingCollection()

collection.list.setCell(for: Model.self,
                        type: ModelCell.self,
                        fill: { $1.movie = $0 },
                        size: { _ in CGSize(width: 150, height: 150) })
```

Next you need to add a function for loading the list of models with offset:

```swift
collection.loadPage = { offset, _, completion in
    // load models with offset and perform a completion(PagedContent(models, next: next)) on main thread
}
```

Perform refresh to load the first page:

```swift
collection.refresh()
```

The wrapper runs loadPage when it reaches the end of the list and the user makes pull-to-refresh action.
At the end of the list the loading indicator is presented. Retry button will be shown when the request is not successful.

## PagingGridLayout and PagingTableLayout

A bridge to SwiftUI for the PagingCollection and PagingTable

```swift
    class ViewModel: ObservableObject {
        let collection = PagingCollection()
        
        override init() {
            super.init()
            collection.loadPage = { [unowned self] _, _, completion in
                // load and perform completion
            }
        }
    }
    
    @StateObject var model = ViewModel()
    
    var body: some View {
        PagingGridLayout(model.collection,
                         setup: {
            $0.list.setCell(for: Model.self,
                            fill: { ModelView(model: $0) },
                            size: { _ in CGSize(width: 150, height: 100) })
        })
        .onFirstAppear {
            model.collection.refresh()
        }
```

## Meta

Ilya Kuznetsov – i.v.kuznecov@gmail.com

Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/ivkuznetsov](https://github.com/ivkuznetsov)
