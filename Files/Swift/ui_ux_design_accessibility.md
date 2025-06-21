# UI/UX Design System & Accessibility Guide for iOS Development in 2025

This comprehensive guide covers best practices for creating robust design systems and ensuring accessibility in iOS applications, with a focus on SwiftUI implementation and modern standards.

## 1. Design Tokens & UI Kit

### 1.1 Understanding Design Tokens

Design tokens are the atomic elements that store visual design attributes. They form the foundation of a design system by defining the core visual properties that will be used throughout an application.

#### Types of Design Tokens

1. **Primitive Tokens**: Foundational values that represent raw design attributes
   - Colors (hex values, RGB values)
   - Typography (font families, weights)
   - Spacing (margin, padding values)
   - Sizing (width, height values)
   - Border radius
   - Shadows
   - Opacity

2. **Semantic Tokens**: Contextual values that apply meaning to primitive tokens
   - Brand colors (primary, secondary, accent)
   - Text styles (heading, body, caption)
   - Component-specific tokens (button colors, input field styles)
   - State-based tokens (active, hover, disabled)

### 1.2 Implementing Design Tokens in SwiftUI

#### Color Tokens Implementation

```swift
// ColorTokens.swift
import SwiftUI

enum ColorTokens {
    // Primitive color tokens
    enum Primitive {
        static let blue100 = Color(hex: "#E6F2FF")
        static let blue500 = Color(hex: "#0066CC")
        static let blue900 = Color(hex: "#003366")
        static let gray100 = Color(hex: "#F8F9FA")
        static let gray300 = Color(hex: "#DEE2E6")
        static let gray500 = Color(hex: "#ADB5BD")
        static let gray900 = Color(hex: "#212529")
        static let green500 = Color(hex: "#28A745")
        static let red500 = Color(hex: "#DC3545")
    }
    
    // Semantic color tokens
    enum Semantic {
        static let primaryBackground = Primitive.gray100
        static let secondaryBackground = Color.white
        static let primaryText = Primitive.gray900
        static let secondaryText = Primitive.gray500
        static let primaryAccent = Primitive.blue500
        static let success = Primitive.green500
        static let error = Primitive.red500
        static let border = Primitive.gray300
    }
}

// Helper extension for hex color initialization
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

#### Typography Tokens Implementation

```swift
// TypographyTokens.swift
import SwiftUI

enum TypographyTokens {
    // Primitive typography tokens
    enum FontFamily {
        static let primary = "SF Pro"
        static let secondary = "SF Pro Rounded"
    }
    
    enum FontWeight {
        static let regular = Font.Weight.regular
        static let medium = Font.Weight.medium
        static let semibold = Font.Weight.semibold
        static let bold = Font.Weight.bold
    }
    
    enum FontSize {
        static let xs = 12.0
        static let sm = 14.0
        static let md = 16.0
        static let lg = 18.0
        static let xl = 20.0
        static let xxl = 24.0
        static let xxxl = 30.0
    }
    
    // Semantic typography tokens
    enum TextStyle {
        static let largeTitle = Font.system(size: FontSize.xxxl, weight: FontWeight.bold)
        static let title1 = Font.system(size: FontSize.xxl, weight: FontWeight.bold)
        static let title2 = Font.system(size: FontSize.xl, weight: FontWeight.semibold)
        static let title3 = Font.system(size: FontSize.lg, weight: FontWeight.semibold)
        static let headline = Font.system(size: FontSize.md, weight: FontWeight.semibold)
        static let body = Font.system(size: FontSize.md, weight: FontWeight.regular)
        static let callout = Font.system(size: FontSize.sm, weight: FontWeight.medium)
        static let subheadline = Font.system(size: FontSize.sm, weight: FontWeight.regular)
        static let footnote = Font.system(size: FontSize.xs, weight: FontWeight.regular)
    }
}
```

#### Spacing and Layout Tokens

```swift
// SpacingTokens.swift
import SwiftUI

enum SpacingTokens {
    // Primitive spacing tokens
    static let xxxs = 2.0
    static let xxs = 4.0
    static let xs = 8.0
    static let sm = 12.0
    static let md = 16.0
    static let lg = 24.0
    static let xl = 32.0
    static let xxl = 48.0
    static let xxxl = 64.0
    
    // Semantic spacing tokens
    enum Layout {
        static let screenEdgePadding = SpacingTokens.md
        static let contentSpacing = SpacingTokens.sm
        static let sectionSpacing = SpacingTokens.lg
        static let cardPadding = SpacingTokens.md
        static let inputFieldPadding = SpacingTokens.sm
    }
}
```

### 1.3 Creating a Comprehensive Design System

A complete design system combines design tokens with reusable components and clear usage guidelines. Here's how to structure a SwiftUI design system:

#### Component Library Structure

```
DesignSystem/
├── Tokens/
│   ├── ColorTokens.swift
│   ├── TypographyTokens.swift
│   ├── SpacingTokens.swift
│   ├── BorderTokens.swift
│   └── ShadowTokens.swift
│
├── Components/
│   ├── Buttons/
│   │   ├── PrimaryButton.swift
│   │   ├── SecondaryButton.swift
│   │   └── IconButton.swift
│   │
│   ├── Cards/
│   │   ├── StandardCard.swift
│   │   └── ActionCard.swift
│   │
│   ├── Inputs/
│   │   ├── TextField.swift
│   │   ├── Toggle.swift
│   │   └── Slider.swift
│   │
│   └── Navigation/
│       ├── TabBar.swift
│       └── NavigationBar.swift
│
└── Modifiers/
    ├── CardModifier.swift
    ├── ShadowModifier.swift
    └── RoundedCornerModifier.swift
```

#### Example Component Using Design Tokens

```swift
// PrimaryButton.swift
import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    let isEnabled: Bool
    
    init(title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypographyTokens.TextStyle.headline)
                .padding(.vertical, SpacingTokens.xs)
                .padding(.horizontal, SpacingTokens.md)
                .frame(maxWidth: .infinity)
        }
        .background(isEnabled ? ColorTokens.Semantic.primaryAccent : ColorTokens.Semantic.secondaryText)
        .foregroundColor(.white)
        .cornerRadius(8)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint("Activates \(title) function")
    }
}
```

### 1.4 Design Token Management Tools

Several tools can help manage design tokens across platforms:

1. **Style Dictionary**: An open-source tool that allows you to define design tokens once and export them to multiple platforms
2. **Theo**: Salesforce's cross-platform design token manager
3. **Figma Tokens**: A Figma plugin that helps manage and export design tokens
4. **Zeplin**: Design handoff tool with design token export capabilities

### 1.5 Best Practices for Design Tokens

1. **Single Source of Truth**: Maintain tokens in one location and generate platform-specific implementations
2. **Naming Conventions**: Use clear, consistent naming patterns (e.g., `color.background.primary`)
3. **Documentation**: Document the purpose and usage of each token
4. **Version Control**: Track changes to design tokens in version control
5. **Automation**: Automate the generation of token files from design tools

## 2. Atomic Design System Implementation

### 2.1 Understanding Atomic Design

Atomic design is a methodology for creating design systems with five distinct levels:

1. **Atoms**: Basic building blocks (buttons, inputs, labels)
2. **Molecules**: Simple groups of UI elements functioning together (search form, menu item)
3. **Organisms**: Complex UI components composed of molecules and atoms (header, product grid)
4. **Templates**: Page-level objects that place components into a layout
5. **Pages**: Specific instances of templates with real content

### 2.2 Implementing Atomic Design in SwiftUI

#### Atoms (Basic Components)

```swift
// Label.swift (Atom)
struct AppLabel: View {
    let text: String
    let style: LabelStyle
    
    enum LabelStyle {
        case title, subtitle, body
    }
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(textColor)
    }
    
    private var font: Font {
        switch style {
        case .title:
            return TypographyTokens.TextStyle.title2
        case .subtitle:
            return TypographyTokens.TextStyle.headline
        case .body:
            return TypographyTokens.TextStyle.body
        }
    }
    
    private var textColor: Color {
        switch style {
        case .title:
            return ColorTokens.Semantic.primaryText
        case .subtitle, .body:
            return ColorTokens.Semantic.secondaryText
        }
    }
}
```

#### Molecules (Combined Components)

```swift
// SearchBar.swift (Molecule)
struct SearchBar: View {
    @Binding var searchText: String
    var placeholder: String
    var onSearch: () -> Void
    
    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ColorTokens.Semantic.secondaryText)
            
            TextField(placeholder, text: $searchText)
                .font(TypographyTokens.TextStyle.body)
                .foregroundColor(ColorTokens.Semantic.primaryText)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ColorTokens.Semantic.secondaryText)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Semantic.secondaryBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorTokens.Semantic.border, lineWidth: 1)
        )
    }
}
```

#### Organisms (Complex Components)

```swift
// ProductCard.swift (Organism)
struct ProductCard: View {
    let product: Product
    let onAddToCart: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            // Product image
            Image(product.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 180)
                .clipped()
                .accessibilityLabel(product.imageDescription)
            
            // Product info
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                AppLabel(text: product.name, style: .title)
                
                AppLabel(text: product.category, style: .subtitle)
                
                HStack {
                    AppLabel(text: "$\(product.price, specifier: "%.2f")", style: .title)
                    Spacer()
                    
                    // Add to cart button
                    PrimaryButton(title: "Add to Cart", action: onAddToCart)
                        .frame(width: 120)
                }
                .padding(.top, SpacingTokens.xs)
            }
            .padding(SpacingTokens.sm)
        }
        .background(ColorTokens.Semantic.secondaryBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
```

#### Templates (Layout Structures)

```swift
// ProductListTemplate.swift (Template)
struct ProductListTemplate<Header: View, Footer: View>: View {
    let title: String
    let products: [Product]
    let onAddToCart: (Product) -> Void
    let header: Header
    let footer: Footer
    
    init(
        title: String,
        products: [Product],
        onAddToCart: @escaping (Product) -> Void,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.products = products
        self.onAddToCart = onAddToCart
        self.header = header()
        self.footer = footer()
    }
    
    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            // Header
            header
            
            // Title
            HStack {
                AppLabel(text: title, style: .title)
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.Layout.screenEdgePadding)
            
            // Product grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: SpacingTokens.md),
                    GridItem(.flexible(), spacing: SpacingTokens.md)
                ], spacing: SpacingTokens.md) {
                    ForEach(products) { product in
                        ProductCard(product: product) {
                            onAddToCart(product)
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.Layout.screenEdgePadding)
            }
            
            // Footer
            footer
        }
        .background(ColorTokens.Semantic.primaryBackground)
    }
}
```

#### Pages (Specific Implementations)

```swift
// FeaturedProductsPage.swift (Page)
struct FeaturedProductsPage: View {
    @StateObject private var viewModel = ProductViewModel()
    @State private var searchText = ""
    
    var body: some View {
        ProductListTemplate(
            title: "Featured Products",
            products: viewModel.featuredProducts,
            onAddToCart: { product in
                viewModel.addToCart(product)
            },
            header: {
                VStack(spacing: SpacingTokens.sm) {
                    SearchBar(
                        searchText: $searchText,
                        placeholder: "Search products",
                        onSearch: { viewModel.searchProducts(query: searchText) }
                    )
                    .padding(.horizontal, SpacingTokens.Layout.screenEdgePadding)
                    
                    // Category filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: SpacingTokens.xs) {
                            ForEach(viewModel.categories, id: \.self) { category in
                                CategoryChip(
                                    title: category,
                                    isSelected: viewModel.selectedCategory == category,
                                    onTap: { viewModel.selectCategory(category) }
                                )
                            }
                        }
                        .padding(.horizontal, SpacingTokens.Layout.screenEdgePadding)
                    }
                }
                .padding(.vertical, SpacingTokens.sm)
                .background(ColorTokens.Semantic.secondaryBackground)
            },
            footer: {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                }
            }
        )
        .navigationTitle("Shop")
        .onAppear {
            viewModel.loadFeaturedProducts()
        }
    }
}
```

### 2.3 Benefits of Atomic Design in SwiftUI

1. **Consistency**: Ensures UI elements are consistent across the application
2. **Reusability**: Promotes component reuse, reducing redundant code
3. **Maintainability**: Makes it easier to update and maintain the design system
4. **Scalability**: Allows the design system to grow with the application
5. **Collaboration**: Improves communication between designers and developers

## 3. Accessibility Implementation

### 3.1 WCAG 2.2 AA Compliance in iOS

The Web Content Accessibility Guidelines (WCAG) 2.2 AA standard provides a framework for making digital content more accessible. Key principles include:

1. **Perceivable**: Information must be presentable to users in ways they can perceive
2. **Operable**: User interface components must be operable
3. **Understandable**: Information and operation must be understandable
4. **Robust**: Content must be robust enough to be interpreted by a variety of user agents

#### Key WCAG 2.2 AA Requirements for iOS Apps

1. **Text Alternatives**: Provide text alternatives for non-text content
2. **Time-Based Media**: Provide alternatives for time-based media
3. **Adaptable Content**: Create content that can be presented in different ways
4. **Distinguishable Content**: Make it easier for users to see and hear content
5. **Keyboard Accessible**: Make all functionality available from a keyboard
6. **Enough Time**: Provide users enough time to read and use content
7. **Seizures and Physical Reactions**: Do not design content in a way that causes seizures
8. **Navigable**: Provide ways to help users navigate and find content
9. **Input Modalities**: Make it easier for users to operate functionality through various inputs
10. **Readable**: Make text content readable and understandable
11. **Predictable**: Make pages appear and operate in predictable ways
12. **Input Assistance**: Help users avoid and correct mistakes

### 3.2 VoiceOver Implementation

VoiceOver is Apple's screen reader technology that enables users with visual impairments to use their devices.

#### Basic VoiceOver Properties

```swift
// Basic accessibility properties
Button("Save") {
    // Action
}
.accessibilityLabel("Save document")
.accessibilityHint("Saves the current document to your iCloud Drive")
.accessibilityAddTraits(.isButton)
```

#### Grouping Elements for VoiceOver

```swift
// Grouping related elements
HStack {
    Image(systemName: "star.fill")
    Text("4.5")
    Text("(234 reviews)")
}
.accessibilityElement(children: .combine)
.accessibilityLabel("4.5 stars based on 234 reviews")
```

#### Custom Actions

```swift
// Custom actions
.accessibilityAction(named: "Delete") {
    viewModel.deleteItem()
}
.accessibilityAction(named: "Favorite") {
    viewModel.favoriteItem()
}
```

#### Announcing Changes

```swift
// Announcing changes to the user
.onChange(of: isLoading) { newValue in
    if !newValue {
        UIAccessibility.post(notification: .announcement, argument: "Content loaded")
    }
}
```

### 3.3 Dynamic Type Support

Dynamic Type allows users to adjust the text size across the system to improve readability.

#### Supporting Dynamic Type

```swift
// Basic Dynamic Type support
Text("Hello, World!")
    .font(.body) // Uses the system's dynamic type sizes

// With custom scaling
Text("Hello, World!")
    .font(.system(size: 16, weight: .regular, design: .default))
    .dynamicTypeSize(.large ... .accessibility3)
```

#### Custom Text Styles with Dynamic Type

```swift
// Custom text style with Dynamic Type support
struct ScaledFont: ViewModifier {
    let name: String
    let size: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(.custom(name, size: size, relativeTo: .body))
    }
}

extension View {
    func scaledFont(name: String, size: CGFloat) -> some View {
        modifier(ScaledFont(name: name, size: size))
    }
}

// Usage
Text("Custom Font Text")
    .scaledFont(name: "CustomFont-Regular", size: 16)
```

### 3.4 Color Contrast and Dark Mode

Ensuring proper color contrast is essential for users with visual impairments.

#### Color Contrast Requirements

- Normal text: 4.5:1 contrast ratio
- Large text: 3:1 contrast ratio

#### Implementing Accessible Colors

```swift
// Color extension for contrast checking
extension Color {
    func contrastRatio(with color: Color) -> CGFloat {
        // Implementation of contrast ratio calculation
        // Returns a value that should be >= 4.5 for normal text
        // and >= 3.0 for large text
    }
    
    var isAccessible: Bool {
        self.contrastRatio(with: .white) >= 4.5 || 
        self.contrastRatio(with: .black) >= 4.5
    }
}
```

#### Supporting Dark Mode

```swift
// Color set that adapts to dark mode
struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var backgroundColor: Color {
        colorScheme == .dark ? 
            ColorTokens.Semantic.darkModeBackground : 
            ColorTokens.Semantic.lightModeBackground
    }
    
    var textColor: Color {
        colorScheme == .dark ? 
            ColorTokens.Semantic.darkModeText : 
            ColorTokens.Semantic.lightModeText
    }
    
    var body: some View {
        Text("Hello, World!")
            .foregroundColor(textColor)
            .background(backgroundColor)
    }
}
```

### 3.5 Accessibility Identifiers for Testing

Accessibility identifiers help with UI testing by providing stable references to UI elements.

```swift
// Adding accessibility identifiers
TextField("Username", text: $username)
    .accessibilityIdentifier("username_field")

Button("Login") {
    // Login action
}
.accessibilityIdentifier("login_button")
```

### 3.6 Comprehensive Accessibility Checklist

1. **VoiceOver Support**
   - All interactive elements have appropriate labels
   - Custom actions are provided where needed
   - Elements are properly grouped
   - Changes in state are announced

2. **Dynamic Type**
   - All text scales appropriately with system settings
   - Layout adapts to larger text sizes
   - Custom fonts support dynamic type

3. **Color and Contrast**
   - Color is not the only means of conveying information
   - Text meets minimum contrast requirements
   - UI is fully functional in dark mode

4. **Reduced Motion**
   - Animations respect the reduced motion setting
   - Essential animations are subtle

5. **Keyboard and Switch Control**
   - All interactive elements are focusable
   - Focus order is logical
   - Focus indicators are visible

6. **Touch Targets**
   - Interactive elements are at least 44x44 points
   - Adequate spacing between touch targets

7. **Testing**
   - Accessibility Inspector is used to verify elements
   - VoiceOver testing is performed regularly
   - UI tests use accessibility identifiers

## 4. Localization and Internationalization

### 4.1 Setting Up Localization

```swift
// Localizable.strings (English)
"greeting" = "Hello, %@!";
"items_count" = "%d items";

// Localizable.strings (Spanish)
"greeting" = "¡Hola, %@!";
"items_count" = "%d artículos";
```

### 4.2 Using Localized Strings

```swift
// Basic localization
Text(NSLocalizedString("greeting", comment: "Greeting message"))

// With string interpolation
Text(String(format: NSLocalizedString("greeting", comment: ""), username))

// Using SwiftUI's LocalizedStringKey
Text("greeting")

// Pluralization
Text(String.localizedStringWithFormat(
    NSLocalizedString("items_count", comment: "Number of items"),
    itemCount
))
```

### 4.3 Supporting Right-to-Left Languages

```swift
// SwiftUI automatically handles RTL layout
HStack {
    Image(systemName: "arrow.left")
    Text("Back")
}
// Will automatically flip in RTL languages

// For custom views that need explicit RTL handling
.environment(\.layoutDirection, .rightToLeft) // For testing
```

## 5. Best Practices for UI/UX Implementation

### 5.1 Performance Optimization

1. **Lazy Loading**
   ```swift
   // Use LazyVStack and LazyHStack for large lists
   LazyVStack {
       ForEach(items) { item in
           ItemRow(item: item)
       }
   }
   ```

2. **View Recycling**
   ```swift
   // Use List for better performance with large datasets
   List(items) { item in
       ItemRow(item: item)
   }
   ```

3. **Avoid Expensive Operations in View Body**
   ```swift
   // Bad practice
   var body: some View {
       Text(expensiveComputation()) // Called every time view updates
   }
   
   // Good practice
   var computedValue: String {
       expensiveComputation()
   }
   
   var body: some View {
       Text(computedValue) // Computed once per view instance
   }
   ```

### 5.2 Responsive Design

1. **GeometryReader for Adaptive Layouts**
   ```swift
   GeometryReader { geometry in
       if geometry.size.width > 500 {
           HStack {
               Image("profile")
               Text("User Profile")
           }
       } else {
           VStack {
               Image("profile")
               Text("User Profile")
           }
       }
   }
   ```

2. **Device Adaptation**
   ```swift
   @Environment(\.horizontalSizeClass) var horizontalSizeClass
   
   var body: some View {
       if horizontalSizeClass == .compact {
           MobileLayout()
       } else {
           TabletLayout()
       }
   }
   ```

### 5.3 Animation and Transitions

1. **Implicit Animations**
   ```swift
   Circle()
       .frame(width: isExpanded ? 200 : 100)
       .animation(.spring(), value: isExpanded)
   ```

2. **Explicit Animations**
   ```swift
   Button("Animate") {
       withAnimation(.easeInOut(duration: 0.5)) {
           isExpanded.toggle()
       }
   }
   ```

3. **Custom Transitions**
   ```swift
   if showDetail {
       DetailView()
           .transition(.asymmetric(
               insertion: .scale.combined(with: .opacity),
               removal: .opacity
           ))
   }
   ```

### 5.4 Error Handling and Feedback

1. **User Feedback**
   ```swift
   struct ErrorView: View {
       let error: Error
       let retryAction: () -> Void
       
       var body: some View {
           VStack(spacing: SpacingTokens.md) {
               Image(systemName: "exclamationmark.triangle")
                   .font(.system(size: 50))
                   .foregroundColor(ColorTokens.Semantic.error)
               
               Text("Something went wrong")
                   .font(TypographyTokens.TextStyle.title2)
               
               Text(error.localizedDescription)
                   .font(TypographyTokens.TextStyle.body)
                   .multilineTextAlignment(.center)
               
               Button("Try Again") {
                   retryAction()
               }
               .buttonStyle(PrimaryButtonStyle())
           }
           .padding()
           .accessibilityElement(children: .combine)
           .accessibilityLabel("Error: \(error.localizedDescription)")
       }
   }
   ```

2. **Loading States**
   ```swift
   struct LoadingView<Content: View>: View {
       let isLoading: Bool
       let content: Content
       
       init(isLoading: Bool, @ViewBuilder content: () -> Content) {
           self.isLoading = isLoading
           self.content = content()
       }
       
       var body: some View {
           ZStack {
               content
                   .disabled(isLoading)
                   .blur(radius: isLoading ? 3 : 0)
               
               if isLoading {
                   VStack {
                       ProgressView()
                           .scaleEffect(1.5)
                       
                       Text("Loading...")
                           .font(TypographyTokens.TextStyle.headline)
                           .padding(.top, SpacingTokens.md)
                   }
                   .frame(width: 150, height: 150)
                   .background(Color.white.opacity(0.8))
                   .cornerRadius(20)
                   .shadow(radius: 10)
               }
           }
           .accessibilityElement(children: .ignore)
           .accessibilityLabel(isLoading ? "Loading content" : "Content loaded")
       }
   }
   ```

## 6. Common Mistakes and Solutions

### 6.1 Design System Mistakes

| Mistake | Impact | Solution |
|---------|--------|----------|
| Inconsistent token naming | Confusion, maintenance issues | Establish clear naming conventions (e.g., `color.background.primary`) |
| Hardcoded values | Inconsistency, difficult updates | Always reference design tokens instead of hardcoding values |
| Too many tokens | Complexity, confusion | Limit primitive tokens, focus on semantic tokens |
| Lack of documentation | Misuse, inconsistency | Document purpose and usage of each token |
| No dark mode support | Poor accessibility, user experience | Ensure all tokens have dark mode variants |

### 6.2 Accessibility Mistakes

| Mistake | Impact | Solution |
|---------|--------|----------|
| Missing accessibility labels | Screen readers can't describe UI | Add `.accessibilityLabel()` to all interactive elements |
| Poor color contrast | Content unreadable for some users | Ensure 4.5:1 contrast ratio for normal text |
| Small touch targets | Difficult to interact with UI | Make touch targets at least 44x44 points |
| No Dynamic Type support | Text may be too small | Use system fonts or `.dynamicTypeSize()` |
| Relying on color alone | Information lost for colorblind users | Use multiple cues (icons, text, patterns) |

### 6.3 SwiftUI Implementation Mistakes

| Mistake | Impact | Solution |
|---------|--------|----------|
| Complex view bodies | Poor performance, difficult maintenance | Extract subviews, use `@ViewBuilder` functions |
| Excessive state updates | Performance issues, UI glitches | Minimize state changes, use derived state |
| Improper view hierarchy | Layout issues, performance problems | Keep view hierarchy shallow, use containers wisely |
| Ignoring safe areas | Content cut off by device features | Respect safe areas or use `.edgesIgnoringSafeArea()` consciously |
| Overusing GeometryReader | Performance impact | Use only when necessary, prefer built-in layout system |

## 7. Conclusion

Creating a robust design system with proper accessibility support is essential for modern iOS applications. By implementing design tokens, following atomic design principles, and ensuring accessibility compliance, you can create apps that are consistent, maintainable, and inclusive.

Remember that a design system is a living entity that should evolve with your application and user needs. Regular audits, user testing, and updates will ensure your design system remains effective and relevant.

## References

1. Apple Developer Documentation. (2025). Human Interface Guidelines: Accessibility. Retrieved from https://developer.apple.com/design/human-interface-guidelines/accessibility
2. Think-it. (2024, July 11). Atomic Design System in SwiftUI. Retrieved from https://think-it.io/insights/Atomic-Design-System-in-SwiftUI
3. Commit Studio. (2025, March 8). Accessibility in SwiftUI Apps: Best Practices. Retrieved from https://medium.com/@commit.studio/accessibility-in-swiftui-apps-best-practices-a15450ebf554
4. Kandula, S. (2025, April 5). Design (Tokens) as Code | Back to the future for the enterprise design systems. Design Systems Collective. Retrieved from https://www.designsystemscollective.com/design-tokens-as-code-back-to-the-future-for-the-enterprise-design-systems-d9d52f2c8e20
5. Jasoliya, D. (2025, March 31). Enhancing Accessibility in SwiftUI: VoiceOver, Dynamic Type & More. Medium. Retrieved from https://medium.com/@dhavaljasoliya8/enhancing-accessibility-in-swiftui-voiceover-dynamic-type-more-bc4108f79bfe
6. W3C. (2024, December 12). Web Content Accessibility Guidelines (WCAG) 2.2. Retrieved from https://www.w3.org/TR/WCAG22/
7. CVS Health. (2025). iOS SwiftUI Accessibility Techniques. GitHub. Retrieved from https://github.com/cvs-health/ios-swiftui-accessibility-techniques
8. Halodoc Blog. (2023, March 23). Simplifying iOS Apps Design with Design Tokens. Retrieved from https://blogs.halodoc.io/simplifying-ios-app-design-with-design-tokens/
9. DesignRush. (2025, April 7). What Are Design Tokens? A Comprehensive Guide. Retrieved from https://www.designrush.com/best-designs/websites/trends/what-are-design-tokens
