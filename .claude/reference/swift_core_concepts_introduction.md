# Chapter 2: Swift Core Concepts

Welcome to the core of the Swift language. This chapter introduces the fundamental building blocks you'll use to construct any Swift application. We'll cover everything from basic syntax to the powerful data structures that make Swift a modern and expressive language.

---

### **1. Basic Syntax**

At the heart of any programming language is its syntax. Swift’s syntax is designed to be clean, readable, and concise.

#### **Constants and Variables**
In Swift, you declare data containers as either constants or variables.

-   A **constant**, declared with `let`, is a value that cannot be changed once it's set. It's immutable.
-   A **variable**, declared with `var`, is a value that can be modified after its initial assignment. It's mutable.

> **Best Practice**: Always use `let` by default and only change it to `var` if you know you need to modify the value. This practice promotes safer, more predictable code.

```swift
// A constant holding the name of a planet. It cannot be changed.
let planetName = "Earth"

// A variable for the current visitor count, which can change.
var visitorCount = 150
visitorCount = 152 // This is valid

// planetName = "Mars" // This would cause a compile-time error
```

#### **Type Annotations and Type Inference**
Swift is a type-safe language, meaning every variable and constant has a specific type, like `String` or `Int`.

-   **Type Inference**: In most cases, you don't need to specify the type. Swift is smart enough to infer it from the initial value you provide. This keeps your code clean and readable.

-   **Type Annotation**: If you need to be explicit, or if a variable won't have an initial value, you can declare its type using a colon (`:`).

```swift
// Type Inference: Swift knows 'appName' is a String and 'version' is a Double.
let appName = "Galaxy Explorer"
let version = 1.2

// Type Annotation: Explicitly declaring the type.
// This is useful when the initial value is not present or could be ambiguous.
let companyName: String = "Stellar Apps"
var currentMission: String? // An optional String, which we will cover later.
```

---

### **2. Fundamental Data Types**

Swift comes with a standard library of basic data types for numbers, text, and logical values.

| Type | Description | Example |
| :--- | :--- | :--- |
| **Integers** | Whole numbers without a fractional component. `Int` is the most common type, automatically matching the platform's native word size (e.g., 64-bit on a 64-bit platform). | `let score: Int = 100` |
| **Floating-Point** | Numbers with a fractional component. `Double` represents a 64-bit floating-point number and is the default type. `Float` is a 32-bit floating-point number. | `let pi: Double = 3.14159` |
| **Booleans** | Logical values that can only be `true` or `false`. Essential for control flow. | `let isAuthenticated: Bool = true` |
| **Strings** | An ordered collection of characters used to represent text. Swift's `String` type is powerful and Unicode-compliant. | `let message: String = "Hello, Swift!"` |
| **Characters** | A single character. While less common than strings, they are useful in specific text-processing scenarios. | `let firstLetter: Character = "A"` |

**String Interpolation** is a key feature that allows you to embed constants and variables directly inside a string literal.

```swift
let starName = "Proxima Centauri"
let distance = 4.24
let discoveryYear = 1915

// Use string interpolation to build a descriptive string.
let starFact = "\(starName) is \(distance) light-years away and was discovered in \(discoveryYear)."
print(starFact)
// Output: Proxima Centauri is 4.24 light-years away and was discovered in 1915.
```

---

### **3. Collection Types**

Swift provides three primary collection types for storing groups of values. These types are implemented as generic collections, meaning they are type-safe and can store any specified type of value.

#### **Arrays**
An `Array` is an ordered collection of values of the same type. The same value can appear multiple times.

```swift
// Creating an array of strings
var planets = ["Mercury", "Venus", "Earth", "Mars"]

// Accessing an element by its index (zero-based)
let thirdPlanet = planets[2] // "Earth"

// Adding a new element to the end of the array
planets.append("Jupiter")

// Iterating over an array
for planet in planets {
    print("Visiting \(planet)...")
}
```

#### **Dictionaries**
A `Dictionary` stores unordered key-value pairs. Each key must be unique, and it maps to a specific value.

```swift
// Creating a dictionary mapping planet names (String) to their number of moons (Int)
var moonCount = [
    "Earth": 1,
    "Mars": 2,
    "Jupiter": 95
]

// Accessing a value by its key. Note: This returns an optional value.
let earthMoons = moonCount["Earth"] // Optional(1)

// Adding or updating a key-value pair
moonCount["Saturn"] = 146 // Adds a new entry
moonCount["Mars"] = 3   // Updates the existing entry for "Mars"

// Iterating over a dictionary
for (planet, count) in moonCount {
    print("\(planet) has \(count) moon(s).")
}
```

#### **Sets**
A `Set` is an unordered collection of unique values of the same type. Use a set when the order of items is not important and you need to ensure each item appears only once.

```swift
// Creating a set of programming languages
var programmingLanguages: Set<String> = ["Swift", "Python", "JavaScript"]

// Adding a new element. If it already exists, nothing happens.
programmingLanguages.insert("Swift") // No change, already present
programmingLanguages.insert("Go")   // "Go" is added

// Checking for membership
if programmingLanguages.contains("Python") {
    print("Python is a supported language.")
}
```

---

### **4. Control Flow**

Control flow statements allow you to control the execution path of your code based on certain conditions or by repeating tasks.

#### **For-In Loops**
Used to iterate over a sequence, such as an array, a range of numbers, or characters in a string.

```swift
// Looping through a range of numbers
for i in 1...5 {
    print("This is loop number \(i)")
}

// Looping through an array
let crew = ["Kirk", "Spock", "McCoy"]
for member in crew {
    print("Welcome aboard, \(member)!")
}
```

#### **While Loops**
A `while` loop performs a set of statements until a condition becomes `false`. The condition is evaluated *before* each pass through the loop.

```swift
var countdown = 3
while countdown > 0 {
    print("\(countdown)...")
    countdown -= 1
}
print("Liftoff!")
```

#### **If-Else Statements**
Used to execute different blocks of code based on a condition.

```swift
let temperature = 25 // degrees Celsius
if temperature > 30 {
    print("It's a hot day!")
} else if temperature < 10 {
    print("It's cold, bring a jacket.")
} else {
    print("The weather is pleasant.")
}
```

#### **Switch Statements**
A `switch` statement considers a value and compares it against several possible matching patterns. Swift's `switch` statements are incredibly powerful and must be exhaustive, meaning every possible value must be handled.

```swift
let httpStatusCode = 404

switch httpStatusCode {
case 200:
    print("OK")
case 400...499: // Matches a range of values
    print("Client Error")
case 500...599:
    print("Server Error")
case let code where code > 600: // Use a 'where' clause for complex conditions
    print("Unknown error code: \(code)")
default:
    print("Unknown status code")
}
```

---

### **5. Functions**

Functions are self-contained chunks of code that perform a specific task. They are fundamental to organizing and reusing code.

#### **Defining and Calling Functions**
You define a function with the `func` keyword, a name, parameters, and a return type.

```swift
// A simple function with no parameters or return value
func sayHello() {
    print("Hello, Universe!")
}

sayHello() // Calling the function

// A function with a parameter
func greet(person: String) {
    print("Hello, \(person)!")
}

greet(person: "Captain") // Output: Hello, Captain!

// A function with a parameter and a return value
func add(_ a: Int, to b: Int) -> Int {
    return a + b
}

let sum = add(5, to: 10) // sum is 15
```

#### **Function Argument Labels**
Each function parameter has both an *argument label* and a *parameter name*.

-   **Argument Label**: Used when calling the function.
-   **Parameter Name**: Used in the implementation of the function.

By default, parameter names serve as their argument labels. You can specify a different argument label or use an underscore (`_`) to have no argument label.

```swift
// 'from' is the argument label, 'hometown' is the parameter name
func greet(person: String, from hometown: String) {
    print("Hello \(person) from \(hometown)!")
}

// The call site is very readable
greet(person: "Maria", from: "Rio")
```

---

### **6. Closures**

Closures are self-contained blocks of functionality that can be passed around and used in your code. They are similar to lambdas in other languages.

Closures can *capture* and store references to any constants and variables from the context in which they are defined.

```swift
let names = ["Chris", "Alex", "Ewa", "Barry", "Daniella"]

// sorted(by:) takes a closure as its argument to define the sorting logic.
let reversedNames = names.sorted(by: { (s1: String, s2: String) -> Bool in
    return s1 > s2
})

print(reversedNames) // ["Ewa", "Daniella", "Chris", "Barry", "Alex"]
```

#### **Trailing Closures**
If a closure is the last argument to a function, you can write it *after* the function's parentheses. This is called trailing closure syntax and it leads to cleaner code.

```swift
// Using trailing closure syntax for the same sorting operation.
// Swift can also infer the parameter and return types.
let reversedAgain = names.sorted { s1, s2 in s1 > s2 }

// If the closure body is a single expression, you can even omit the 'return'.
// Swift provides shorthand argument names ($0, $1, etc.).
let shortestVersion = names.sorted { $0 > $1 }
```

---

### **7. Structs, Classes, and Enumerations**

Swift provides three powerful ways to define your own custom data types. Choosing the right one is a key part of Swift development.

| Feature | `struct` | `class` | `enum` |
| :--- | :--- | :--- | :--- |
| **Kind** | **Value Type** | **Reference Type** | **Value Type** |
| **Description** | A blueprint for creating custom data types that are copied when passed around. They don't support inheritance. | A blueprint for objects that are passed by reference. Supports inheritance. | Defines a common type for a group of related values. |
| **When to Use** | Use by default. Ideal for data models (`User`, `Point`, `Size`) that don't need inheritance or a shared identity. | When you need Objective-C interoperability, identity (e.g., `FileHandle`), or inheritance. | For modeling a finite set of distinct states or cases (e.g., `NetworkStatus`, `Direction`). |
| **Inheritance** | No | Yes | No |
| **Mutability** | Properties can be changed on `var` instances. Methods that modify properties must be marked `mutating`. | Properties can be changed on both `let` and `var` instances. | Same as `struct`. |

#### **Structs (Value Types)**
Structs are the most common way to model custom data in Swift. When you assign a struct to a new variable or pass it to a function, a full copy is made.

```swift
struct Point {
    var x: Double
    var y: Double
}

var p1 = Point(x: 10, y: 20)
var p2 = p1 // p2 is a *copy* of p1

p2.x = 100 // This only changes p2, not p1

print("p1.x is \(p1.x)") // Output: p1.x is 10
print("p2.x is \(p2.x)") // Output: p2.x is 100
```

#### **Classes (Reference Types)**
Classes are passed by reference. When you assign a class instance to a new variable, both variables refer to the *same* instance in memory.

```swift
class Window {
    var title: String
    init(title: String) {
        self.title = title
    }
}

var w1 = Window(title: "Main")
var w2 = w1 // w2 and w1 now refer to the *same* window instance

w2.title = "Settings" // This changes the title for both w1 and w2

print("w1.title is \(w1.title)") // Output: w1.title is Settings
print("w2.title is \(w2.title)") // Output: w2.title is Settings
```

#### **Enumerations**
Enums allow you to define a type with a finite set of related values. Swift enums can also have **associated values**, which let you store additional information along with each case.

```swift
enum Barcode {
    case upc(Int, Int, Int, Int)
    case qrCode(String)
}

var productBarcode = Barcode.upc(8, 85909, 51226, 3)
productBarcode = .qrCode("ABCDEFGHIJKLMNOP") // Use . a_shortcut when type is known

switch productBarcode {
case .upc(let numberSystem, let manufacturer, let product, let check):
    print("UPC: \(numberSystem), \(manufacturer), \(product), \(check).")
case .qrCode(let productCode):
    print("QR code: \(productCode).")
}
```