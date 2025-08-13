# Advanced Swift Topics

This document explores advanced features of the Swift language that are essential for building sophisticated, performant, and robust applications. Mastery of these concepts is a hallmark of an experienced Swift developer.

---

### **1. Protocols and Protocol-Oriented Programming (POP)**

Protocol-Oriented Programming is a core design paradigm in Swift that favors composition over inheritance. Instead of inheriting capabilities from a superclass, types *conform* to protocols, which define a blueprint of functionality.

#### **What are Protocols?**
A protocol defines a set of methods, properties, or other requirements that a conforming type must implement. It's like a contract that guarantees a certain behavior without dictating the underlying implementation.

You can define and adopt a protocol as follows:

```swift
// 1. Define a protocol
protocol FullyNameable {
    var fullName: String { get }
}

// 2. Conform to the protocol in a struct
struct User: FullyNameable {
    var firstName: String
    var lastName: String

    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}

// 3. Conform to the protocol in a class
class Person: FullyNameable {
    var givenName: String
    var familyName: String

    init(givenName: String, familyName: String) {
        self.givenName = givenName
        self.familyName = familyName
    }

    var fullName: String {
        return "\(givenName) \(familyName)"
    }
}

let user = User(firstName: "Jane", lastName: "Doe")
let person = Person(givenName: "John", familyName: "Appleseed")

print(user.fullName)   // Prints "Jane Doe"
print(person.fullName) // Prints "John Appleseed"
```

#### **Protocol-Oriented vs. Object-Oriented Programming**

| Feature | Object-Oriented Programming (OOP) | Protocol-Oriented Programming (POP) |
| :--- | :--- | :--- |
| **Core Idea** | Inheritance from a single base class. | Composition of behaviors by conforming to multiple protocols. |
| **Type Support** | Primarily for reference types (`class`). | Supports both value types (`struct`, `enum`) and reference types (`class`). |
| **Flexibility** | Can be rigid; "is-a" relationships are locked in at design time. | Highly flexible; types can adopt new behaviors by conforming to new protocols. |
| **Problem** | The "Gorilla/Banana Problem": You want a banana, but you get a gorilla holding the banana and the entire jungle with it. Base classes can become bloated. | Solves this by allowing you to adopt just the "banana" (the specific functionality you need) without the "gorilla" (the monolithic base class). |

#### **Protocol Extensions and Default Implementations**
One of the most powerful features of POP is the ability to extend protocols to provide default implementations for required methods and properties. This allows you to add shared functionality to all conforming types without duplicating code.

```swift
protocol Describable {
    func describe() -> String
}

// Extend the protocol to provide a default implementation
extension Describable {
    func describe() -> String {
        return "This is a default description."
    }
}

struct Item: Describable {
    // No need to implement describe(), it gets the default version.
}

struct Product: Describable {
    var name: String
    // Provide a custom implementation to override the default
    func describe() -> String {
        return "This is a product named \(name)."
    }
}

print(Item().describe())       // Prints "This is a default description."
print(Product(name: "SwiftUI Course").describe()) // Prints "This is a product named SwiftUI Course."
```

#### **Associated Types: Creating Generic Protocols**
Protocols can work with generic types by using `associatedtype`. This allows you to define a protocol where some of the types used in its definition are not specified until the protocol is adopted.

```swift
protocol Container {
    associatedtype Item // Placeholder for the type of item the container holds
    mutating func append(_ item: Item)
    var count: Int { get }
    subscript(i: Int) -> Item { get }
}

// A generic stack that conforms to the Container protocol
struct Stack<Element>: Container {
    // Swift infers that 'Item' is 'Element' for this conformance
    typealias Item = Element
    private var items = [Element]()

    mutating func append(_ item: Element) {
        items.append(item)
    }

    var count: Int {
        return items.count
    }

    subscript(i: Int) -> Element {
        return items[i]
    }
}
```

---

### **2. Generics**

Generics allow you to write flexible, reusable functions and types that can work with any type, subject to constraints you define. This avoids code duplication and provides compile-time type safety.

#### **Generic Functions**
A generic function can operate on values of any type. For example, a function to swap two values can be written generically.

```swift
// A generic function that can swap any two values of the same type
func swapTwoValues<T>(_ a: inout T, _ b: inout T) {
    let temporaryA = a
    a = b
    b = temporaryA
}

var someInt = 3
var anotherInt = 107
swapTwoValues(&someInt, &anotherInt)
// someInt is now 107, and anotherInt is now 3

var someString = "hello"
var anotherString = "world"
swapTwoValues(&someString, &anotherString)
// someString is now "world", and anotherString is now "hello"
```

#### **Generic Types**
You can also define your own generic classes, structures, and enumerations. The `Stack` example from the protocols section is a perfect example of a generic type. Here is another one:

```swift
// A generic type that can hold a pair of values of any two types.
struct Pair<T, U> {
    let first: T
    let second: U
}

// Create an instance with Int and String
let intAndString = Pair(first: 1, second: "two")
print("First: \(intAndString.first), Second: \(intAndString.second)")

// Create an instance with String and Double
let stringAndDouble = Pair(first: "pi", second: 3.14159)
print("First: \(stringAndDouble.first), Second: \(stringAndDouble.second)")
```

---

### **3. Memory Management (ARC)**

Swift uses **Automatic Reference Counting (ARC)** to manage your app’s memory usage. In most cases, this means memory management "just works," and you don't need to think about it. However, ARC can sometimes require more information about the relationships between your objects to manage memory for you.

The most common issue is a **retain cycle**, where two class instances hold strong references to each other, preventing ARC from ever deallocating them. This creates a memory leak.

| Reference Type | Description | When to Use |
| :--- | :--- | :--- |
| **`strong`** | The default reference type. As long as a strong reference to an object exists, it will not be deallocated. | In most cases, for standard ownership relationships (e.g., a view controller owning its view). |
| **`weak`** | A reference that does not keep a strong hold on the instance it refers to. It automatically becomes `nil` when the instance is deallocated. It must be an optional `var`. | To break retain cycles when the other instance has an independent, shorter lifetime. The classic example is a `delegate`. |
| **`unowned`** | A reference that also does not keep a strong hold. However, it is assumed to always have a value. Accessing an unowned reference after its instance has been deallocated will trigger a runtime crash. | When the other instance has the same lifetime or a longer lifetime. Use it only when you are certain the reference will not become `nil`. |

#### **Example of a Retain Cycle and its Solution**
Consider a `Person` and an `Apartment`. A person can own an apartment, and an apartment has a tenant.

```swift
// A classic retain cycle
class Person {
    let name: String
    var apartment: Apartment?
    init(name: String) { self.name = name }
    deinit { print("\(name) is being deinitialized") }
}

class Apartment {
    let unit: String
    // This strong reference back to Person creates the cycle
    var tenant: Person?
    init(unit: String) { self.unit = unit }
    deinit { print("Apartment \(unit) is being deinitialized") }
}

var john: Person? = Person(name: "John Appleseed")
var unit4A: Apartment? = Apartment(unit: "4A")

// Create the strong references
john?.apartment = unit4A
unit4A?.tenant = john

// Set the original variables to nil.
// The deinit methods are never called because of the retain cycle.
john = nil
unit4A = nil
```
![A diagram showing a strong reference cycle between a Person instance and an Apartment instance.](https://docs.swift.org/swift-book/images/ReferenceCycle01@2x.png)

To fix this, we declare the `tenant` property in `Apartment` as `weak`.

```swift
class ApartmentFixed {
    let unit: String
    // Use 'weak' to break the retain cycle
    weak var tenant: Person?
    init(unit: String) { self.unit = unit }
    deinit { print("Apartment \(unit) is being deinitialized") }
}

// ... if you re-run the setup code with ApartmentFixed,
// both deinit methods will be called, and memory will be freed.
```

A common source of retain cycles is with closures that capture `self`. Always use a capture list like `[weak self]` to prevent this.

```swift
class MyViewController {
    var onComplete: (() -> Void)?
    
    func setupCompletionHandler() {
        // Without [weak self], this would create a strong reference cycle.
        onComplete = { [weak self] in
            guard let self = self else { return }
            self.doSomething()
        }
    }
    
    func doSomething() {
        print("Action completed!")
    }
    
    deinit {
        print("MyViewController deinitialized.")
    }
}
```

---

### **4. Modern Concurrency**

Swift provides a modern, powerful concurrency system designed to make writing safe and correct concurrent code easier. It is built on three key pillars: `async/await`, structured concurrency, and actors.

#### **`async`/`await`**
The `async/await` syntax allows you to write asynchronous code that reads like simple, linear, synchronous code. A function can be marked as `async` to indicate it can perform asynchronous work. You call it using the `await` keyword, which suspends the current task until the awaited function returns.

```swift
// An async function that fetches an image from a URL
func fetchImage(from url: URL) async throws -> UIImage {
    let (data, _) = try await URLSession.shared.data(from: url)
    guard let image = UIImage(data: data) else {
        throw FetchError.invalidImageData
    }
    return image
}

// Using the async function inside a Task
Task {
    do {
        let imageUrl = URL(string: "https://example.com/image.png")!
        let downloadedImage = try await fetchImage(from: imageUrl)
        // Update UI on the main thread
        await MainActor.run {
            myImageView.image = downloadedImage
        }
    } catch {
        print("Failed to fetch image: \(error)")
    }
}
```

#### **Structured Concurrency with Task Groups**
Structured concurrency treats concurrent tasks as a single unit of work. If a task is cancelled, all of its sub-tasks are automatically cancelled. A `TaskGroup` allows you to dynamically launch multiple child tasks and collect their results.

```swift
func fetchThumbnails(for ids: [String]) async throws -> [String: UIImage] {
    var thumbnails: [String: UIImage] = [:]
    
    try await withThrowingTaskGroup(of: (String, UIImage).self) { group in
        for id in ids {
            group.addTask {
                let url = URL(string: "https://example.com/\(id).png")!
                // Assuming fetchImage is the async function from the previous example
                let image = try await fetchImage(from: url)
                return (id, image)
            }
        }
        
        // Collect results as they complete
        for try await (id, image) in group {
            thumbnails[id] = image
        }
    }
    
    return thumbnails
}
```

#### **The Actor Model for Data Race Safety**
An **actor** is a special kind of reference type that protects its state from data races. All access to an actor's mutable state must be done asynchronously using `await`. This allows the actor to ensure that only one piece of code can access its state at a time, preventing conflicts.

> **Key Insight**: One of the most complex aspects of actors is **reentrancy**. When an actor method suspends at an `await`, other calls can be made to the actor. This means the actor's state might change during the suspension point. You must not assume state is unchanged across an `await`.

```swift
actor TemperatureLogger {
    private var measurements: [Double] = []
    var max: Double = -Double.infinity

    func log(measurement: Double) {
        measurements.append(measurement)
        if measurement > max {
            max = measurement
        }
    }
    
    // Accessing this property from outside the actor requires 'await'
    var average: Double {
        guard !measurements.isEmpty else { return 0 }
        return measurements.reduce(0, +) / Double(measurements.count)
    }
}

let logger = TemperatureLogger()

Task {
    await logger.log(measurement: 24.5)
    await logger.log(measurement: 26.1)
    
    // Accessing 'average' must be awaited because it's isolated to the actor
    let avg = await logger.average
    print("Average temperature: \(avg)")
}
```
---

### **5. Error Handling**

Swift has first-class support for throwing, catching, propagating, and manipulating recoverable errors. Unlike optionals, which can represent the absence of a value, error handling allows you to determine the underlying cause of a failure and gracefully respond.

#### **Defining Custom Error Types**
The best practice is to define custom errors using an `enum` that conforms to the `Error` protocol. This provides clear, structured error cases.

```swift
enum VendingMachineError: Error {
    case invalidSelection
    case insufficientFunds(coinsNeeded: Int)
    case outOfStock
}
```

#### **Throwing and Propagating Errors**
A function that can fail is marked with the `throws` keyword. Inside the function, you use `throw` to signal that an error has occurred.

```swift
struct Item {
    var price: Int
    var count: Int
}

class VendingMachine {
    var inventory = [
        "Candy Bar": Item(price: 12, count: 7),
        "Chips": Item(price: 10, count: 4)
    ]
    var coinsDeposited = 0

    func vend(itemNamed name: String) throws {
        guard let item = inventory[name] else {
            throw VendingMachineError.invalidSelection
        }
        guard item.count > 0 else {
            throw VendingMachineError.outOfStock
        }
        guard item.price <= coinsDeposited else {
            throw VendingMachineError.insufficientFunds(coinsNeeded: item.price - coinsDeposited)
        }
        
        coinsDeposited -= item.price
        var newItem = item
        newItem.count -= 1
        inventory[name] = newItem
        
        print("Dispensing \(name)")
    }
}
```

#### **Handling Errors**
You have three main ways to handle errors from a throwing function.

**1. `do-catch` Statement**
The `do-catch` statement allows you to handle different error cases with specific logic.

```swift
let machine = VendingMachine()
machine.coinsDeposited = 8

do {
    try machine.vend(itemNamed: "Chips")
} catch VendingMachineError.invalidSelection {
    print("Invalid selection.")
} catch VendingMachineError.outOfStock {
    print("Out of stock.")
} catch VendingMachineError.insufficientFunds(let coinsNeeded) {
    print("Insufficient funds. Please insert an additional \(coinsNeeded) coins.")
} catch {
    print("Unexpected error: \(error).")
}
// Prints: "Insufficient funds. Please insert an additional 2 coins."
```

**2. `try?` - Converting to an Optional**
Use `try?` to handle an error by converting it to an optional value. If an error is thrown, the expression's value is `nil`.

```swift
// If vend() throws an error, the result is nil. Otherwise, it's ().
let success = try? machine.vend(itemNamed: "Candy Bar")

if success != nil {
    print("Vending was successful.")
} else {
    print("Vending failed.")
}
```

**3. `try!` - Disabling Error Propagation**
Use `try!` only when you are absolutely certain that a throwing function will *not* throw an error at runtime. If an error is thrown, your app will crash.

```swift
// Use try! only when failure is impossible, e.g., loading a known asset.
// let photo = try! loadImage(named: "guaranteed-photo.jpg")
```