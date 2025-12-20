# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Enso is a modern macOS email client built with SwiftUI for macOS 26.1+. The app features:
- Multi-account IMAP/SMTP email support via SwiftMail library
- On-device AI assistance using Apple's Foundation Models framework
- SwiftData for local persistence
- Liquid Glass design system with custom typography (Instrument Serif)
- Browser-style tab interface with configurable behavior

## Build & Test Commands

### Building
```bash
# Build the project for macOS
xcodebuild -project Enso.xcodeproj -scheme Enso -configuration Debug build

# Build for release
xcodebuild -project Enso.xcodeproj -scheme Enso -configuration Release build

# Clean build folder
xcodebuild -project Enso.xcodeproj -scheme Enso clean
```

### Running
```bash
# Build and run (opens the app)
xcodebuild -project Enso.xcodeproj -scheme Enso -configuration Debug build && open build/Debug/Enso.app
```

### Testing
```bash
# Run all tests
xcodebuild test -project Enso.xcodeproj -scheme Enso

# Run specific test target
xcodebuild test -project Enso.xcodeproj -scheme Enso -only-testing:EnsoTests
```

## Architecture

### Application Structure

```
Enso/
├── Models/              # SwiftData models (@Model macro)
├── Views/               # SwiftUI views organized by feature
│   ├── Onboarding/     # Multi-step welcome flow
│   ├── Main/           # Tab system and main window
│   ├── Mail/           # 3-column email interface
│   ├── Compose/        # Email composition
│   ├── AI/             # AI assistant views
│   ├── Settings/       # App configuration
│   └── Components/     # Reusable UI components
├── ViewModels/         # Observable state managers
├── Services/           # Business logic layer
│   ├── Email/          # IMAP/SMTP operations
│   ├── AI/             # Foundation Models integration
│   └── Security/       # Keychain credential storage
├── Utilities/          # Helpers and extensions
└── Resources/          # Assets, fonts, etc.
```

### Data Layer (SwiftData)

**Models** use the `@Model` macro and are stored in `Models/` directory:
- `Account`: Email account with IMAP/SMTP configuration
- `Email`: Email messages with relationships to folders and attachments
- `Folder`: Mailbox folders (Inbox, Sent, etc.)
- `Attachment`: File attachments with data storage
- `AIConversation` & `AIMessage`: AI chat history

**ModelContainer** is configured in `EnsoApp.swift`:
```swift
.modelContainer(for: [Account.self, Email.self, Folder.self, Attachment.self, AIConversation.self, AIMessage.self])
```

**Accessing Data**:
- `@Environment(\.modelContext)` for insert/delete operations
- `@Query` property wrapper for automatic SwiftData queries
- `FetchDescriptor` for complex queries with sorting/filtering

### Email Integration (SwiftMail)

The app uses [SwiftMail](https://github.com/Cocoanetics/SwiftMail) for IMAP and SMTP operations.

**Key Services**:
- **IMAPService**: Connects to IMAP servers, fetches emails, monitors for new mail (IDLE command)
- **SMTPService**: Sends emails via SMTP with TLS support
- **SyncService**: Background synchronization with IDLE monitoring for real-time updates
- **AttachmentService**: Downloads and manages email attachments

**Important Notes**:
- SwiftMail types must be fully qualified (e.g., `SwiftMail.IMAPServer`) to avoid conflicts with FoundationModels
- Credentials are stored securely in Keychain via `KeychainService`
- IMAP IDLE is used for push-style email notifications
- Sync operations run on background actors to avoid blocking the main thread

### AI Integration (Foundation Models)

The app uses Apple's Foundation Models framework for on-device AI assistance.

**AIService** (`Services/AI/AIService.swift`):
- Wraps `LanguageModelSession` for conversation management
- Provides streaming responses via `AsyncThrowingStream`
- Maintains email context for contextual assistance
- Checks availability with `SystemLanguageModel.default.availability`

**Email Tools** (`Services/AI/EmailTools.swift`):
- Defines AI tools using `@Generable` macro for function calling
- Tools include: search, compose, summarize, get details, mark email, folder stats
- Tools must use `@MainActor` if they access UI-isolated services like `DraftService`

**Access Points**:
- **AI Tab**: Standalone conversation interface (`AITabView`)
- **AI Sidebar**: Contextual assistant that sees the currently selected email (`AISidebarView`)

**Key Patterns**:
```swift
// Check AI availability
await aiService.checkAvailability()
if aiService.isAvailable {
    try await aiService.createSession()
}

// Streaming responses
let stream = try await aiService.sendMessageStreaming(query)
for try await chunk in stream {
    // UI updates handled automatically via @Observable
}
```

### Tab System

**TabManager** (`ViewModels/TabManager.swift`):
- Manages browser-style tabs with configurable behavior
- Tracks selected email for AI context propagation
- Tab types: mail, compose, aiConversation, settings

**Tab Behavior** (configurable in Settings):
- Split Pane + Tabs (default): Email list stays visible
- Auto-open in new tabs: Every action opens a new tab
- Replace current tab: Content replaces current view

### Service Layer

**Core Services**:
- `SyncService`: Orchestrates email synchronization across accounts
- `DraftService`: Auto-saves compose drafts (marked `@MainActor`)
- `SearchService`: Full-text email search
- `AttachmentService`: Attachment download/storage
- `AIService`: Foundation Models integration
- `KeychainService`: Secure credential storage

**Actor Isolation**:
- Services that modify UI state or call UI-isolated APIs must use `@MainActor`
- Background sync operations use unstructured tasks
- Always check actor context when calling between services

### Environment-Based Dependency Injection

Services are injected via SwiftUI environment:
```swift
// Define environment key
private struct AIServiceKey: EnvironmentKey {
    static let defaultValue: AIService = AIService()
}

extension EnvironmentValues {
    var aiService: AIService {
        get { self[AIServiceKey.self] }
        set { self[AIServiceKey.self] = newValue }
    }
}

// Inject in EnsoApp.swift
.environment(\.aiService, aiService)

// Access in views
@Environment(\.aiService) private var aiService
```

## Important Configuration

### Info.plist

**Font Registration**:
```xml
<key>ATSApplicationFontsPath</key>
<string>Fonts</string>
```
Instrument Serif font files are in `Resources/Fonts/` and must be referenced relative to the app bundle.

**Bundle Identifier**: `dev.choki.Enso`

### Entitlements

Required capabilities:
- `com.apple.security.network.client` - IMAP/SMTP network access
- `com.apple.security.keychain-access-groups` - Secure credential storage

### Deployment Target

- **Minimum**: macOS 26.1
- Foundation Models framework requires macOS 26.0+
- Uses latest SwiftUI features (NavigationSplitView, inspector, etc.)

## Design System

### Typography
- **Instrument Serif**: Large titles, onboarding, welcome screens (`.ensoTitle`, `.ensoTitle2`)
- **SF Pro (system)**: All other text

### Liquid Glass Effects

**Overview**: Liquid Glass is Apple's design language introduced at WWDC 2025, representing the biggest visual update to iOS since the move to flat design in iOS 7. Glass elements float above content with translucent, depth-aware surfaces that reflect and refract surrounding content, featuring real-time light bending (lensing), specular highlights responding to device motion, adaptive shadows, and interactive behaviors.

**Core Principle: Use Standard Components First**

Standard SwiftUI components automatically adopt Liquid Glass when building with the latest SDKs. This includes:
- Bars (toolbars, tab bars, navigation bars)
- Sheets and popovers
- Controls (buttons, toggles, sliders)
- Split views and sidebars

**Remove custom styling** and let the system handle appearances. Custom backgrounds and effects can interfere with Liquid Glass.

**When to Use Liquid Glass:**
- Navigation bars and toolbars
- Tab bars and bottom accessories
- Floating action buttons
- Sheets, popovers, and menus
- Context-sensitive controls
- System-level alerts

**When NOT to Use:**
- Content layers (lists, tables, media)
- Full-screen backgrounds
- Scrollable content areas
- Stacked glass layers
- Every UI element (apply sparingly)

#### The `.glassEffect()` Modifier

Use `.glassEffect(_:in:)` modifier ONLY for custom components that need Liquid Glass appearance.

**Basic Usage:**
```swift
Text("Custom Label")
    .padding()
    .glassEffect()  // Applies DefaultGlassEffectShape (capsule) by default
```

**Glass Variants:**

SwiftUI provides three glass effect options:

1. **`.regular`** - The most commonly used across the system. Resembles frosted glass with heavier diffusion, enhancing contrast and improving legibility.
2. **`.clear`** - Designed for dramatic effect. Minimal blurring and high transparency, giving the impression of actual liquid glass.
3. **`.identity`** - Suitable when you need to conditionally disable the effect.

**Customization Options:**

```swift
// With custom shape
Text("Custom Label")
    .padding()
    .glassEffect(.regular, in: .rect(cornerRadius: 16.0))

// With color tinting
Text("Custom Label")
    .padding()
    .glassEffect(.regular.tint(.purple.opacity(0.8)))

// Interactive (responds to touch/hover, handles gestures)
Button("Action") { }
    .glassEffect(.regular.interactive())

// Combined customizations
Button("Action") { }
    .glassEffect(.clear.tint(.blue.opacity(0.7)).interactive())
```

**Key Features:**
- The `.interactive()` modifier makes glass more aggressive to the content behind and handles gestures like tap and drag
- All glass types can be modified using the `.tint()` function
- Reduced opacity in tint colors improves the see-through effect
- The system automatically applies rounded corners fitting your app's context

#### GlassEffectContainer & GlassEffectUnion

The `glassEffectUnion` modifier allows multiple UI elements to be visually grouped into a single unified Liquid Glass shape, creating cohesive glass-morphism designs.

**Implementation Pattern:**

```swift
@Namespace var unionNamespace

GlassEffectContainer(namespace: unionNamespace) {
    HStack {
        Button { ... }
            .glassEffectUnion(id: "toolbar", namespace: unionNamespace)

        Button { ... }
            .glassEffectUnion(id: "toolbar", namespace: unionNamespace)
    }
}
```

**Key Components:**
1. **GlassEffectContainer**: Wraps the content and draws the unified background. Requires a `namespace`.
2. **.glassEffectUnion(id:namespace:)**: applied to EACH item that should be part of the glass shape.
3. **Padding**: Ensure items have sufficient padding *before* applying the modifier, as the union is calculated based on the frame of the view at that point.

**When to Use:**
- Tab bars (floating capsules)
- Toolbar groups
- Action chips

**Note**: Do NOT apply individual background materials to the items. The container handles the drawing.



**When to Use:**
- Vertically or horizontally stacked controls that should appear as one unified glass element
- Grouped toolbar actions (similar to Apple Maps button clusters)
- Related control sets that benefit from visual cohesion

**Key Parameters:**
- `id`: Shared identifier connecting all grouped elements
- `namespace`: SwiftUI `@Namespace` binding for view coordination

#### Morphing Transitions with glassEffectID

The `glassEffectID` modifier enables SwiftUI views that use the glass effect to transform smoothly into one another, creating fluid morphing effects when glass elements transition in and out of view.

**Purpose:**
- Shares a visual identity between elements coordinated by `GlassEffectContainer`
- Allows glass elements to morph seamlessly during view transitions
- Creates polished, Apple-quality animations between states

**Requirements:**
- Each view inside `GlassEffectContainer` needs a unique identifier within a shared namespace
- Elements must exist in the same container view
- SwiftUI tracks views as they're added/removed to create seamless shape transitions

**Implementation Pattern:**

```swift
@Namespace var morphNamespace

GlassEffectContainer {
    if showingFirstView {
        FirstView()
            .glassEffect(.regular)
            .glassEffectID("morphingElement", in: morphNamespace)
    } else {
        SecondView()
            .glassEffect(.regular)
            .glassEffectID("morphingElement", in: morphNamespace)
    }
}
```

**Use Cases:**
- Expanding/collapsing UI elements
- Transitioning between different content states
- Creating hero animations with glass effects
- Morphing between toolbar configurations

#### Button Styles

SwiftUI provides native glass button styles:
- `.buttonStyle(.glass)` - Standard glass appearance for secondary actions
- `.buttonStyle(.glassProminent)` - Emphasized glass appearance for primary actions

The `GlassButtonStyle` applies glass border artwork based on the button's context, providing a consistent system appearance.

#### Glass Background Effect

The `glassBackgroundEffect` modifier fills a view's background with an automatic glass background effect.

**Variations:**

```swift
// With automatic container-relative rounded rectangle shape
.glassBackgroundEffect(displayMode: .always)

// With custom shape
.glassBackgroundEffect(in: .rect(cornerRadius: 20), displayMode: .always)
```

**Display Modes:**
- `.always` - Glass effect always visible
- `.automatic` - System determines when to show the effect based on context

**Context-Aware Behavior:**
In certain contexts (navigation bars on iOS, window toolbars on macOS), toolbar items automatically receive a glass background effect that's shared with other items in the same logical grouping.

**Important Note:**
Available in iOS 26 and macOS 26 (Tahoe), not macOS 15.

#### Liquid Glass Sheets, Popovers, and Menus

On iOS 26, partial height sheets are inset by default with a Liquid Glass background, appearing to float above the interface.

**Sheet Implementation:**

```swift
.sheet(isPresented: $showingSheet) {
    SheetContent()
        .presentationDetents([.medium, .large])  // Required for Liquid Glass
}
```

**Key Requirements:**
- Specify presentation detents with at least one partial height option (`.medium` or custom height)
- **Do NOT use** `.presentationBackground()` - it interferes with automatic Liquid Glass
- Sheets have rounded corners following the device shape
- Edges don't touch the screen, creating a floating appearance

**Forms in Sheets:**

Form views provide their own opaque background that covers the glass surface. To enable Liquid Glass:

```swift
.sheet(isPresented: $showingSettings) {
    NavigationStack {
        Form {
            // Form content
        }
        .scrollContentBackground(.hidden)  // Required for Liquid Glass
    }
    .presentationDetents([.medium, .large])
}
```

**Morphing Sheet Transitions:**

Create smooth zoom transitions from toolbar items to sheets:

```swift
// On the toolbar item
ToolbarItem {
    Button("Show Settings") {
        showingSettings = true
    }
    .matchedTransitionSource(id: "settingsSheet", in: namespace)
}

// On the sheet
.sheet(isPresented: $showingSettings) {
    SettingsView()
        .navigationTransition(.zoom(sourceID: "settingsSheet", in: namespace))
        .presentationDetents([.medium, .large])
}
```

**Behavior:**
Menus, alerts, and popovers flow smoothly out of Liquid Glass controls, drawing focus from their action to the presentation's content.

#### Search Interface

Use the native `.searchable()` modifier instead of custom search implementations:

```swift
NavigationSplitView {
    // sidebar
} content: {
    ContentList()
        .searchable(text: $searchText, prompt: "Search emails...")
        .searchScopes($scope) {
            Text("All Mail").tag(SearchScope.all)
            Text("Current Folder").tag(SearchScope.currentFolder)
        }
        .searchSuggestions {
            ForEach(searchHistory, id: \.self) { query in
                Text(query).searchCompletion(query)
            }
        }
} detail: {
    // detail view
}
```

Benefits:
- Uses native Liquid Glass automatically
- Handles keyboard activation properly
- Provides scope picker with system styling
- Supports search suggestions natively
- Works correctly across different size classes

#### What NOT to Do

1. **Don't overuse Liquid Glass** - Apply sparingly to only the most important functional elements
2. **Don't add custom backgrounds** to bars, sheets, or popovers - they interfere with system effects
3. **Don't stack glass effects** on top of each other - causes visual noise
4. **Don't use `.ultraThinMaterial`** for search headers - use native searchable modifier instead
5. **Don't create custom search fields** when `.searchable()` works
6. **Don't use `.presentationBackground()`** on iOS 26 sheets - it prevents automatic Liquid Glass
7. **Don't apply glass to content layers** - lists, tables, and media should remain opaque
8. **Don't forget `.scrollContentBackground(.hidden)`** when using Forms in glass sheets
9. **Don't apply glass to full-screen backgrounds** - it should float "on top" as an overlay layer

#### Best Practices Summary

**Layered Design Philosophy:**
Liquid Glass should sit "on top" of your UI as an overlay layer, not replace main content areas. Think of it as a floating interface layer that hovers above your core content.

**Performance:**
- Use `GlassEffectContainer` to group related glass elements for better rendering performance
- Elements within the same container merge visually when positioned closely

**Visual Hierarchy:**
- Use reduced opacity in tint colors to improve the see-through effect
- Reserve `.glassProminent` for primary actions
- Use `.glass` for secondary actions

## Common Patterns

### Adding a New Email Tool

1. Define input struct with `@Generable`:
```swift
@Generable
struct MyToolInput: Sendable {
    @Guide(description: "Parameter description for AI")
    var myParam: String
}
```

2. Implement Tool protocol:
```swift
@MainActor  // If accessing DraftService or other MainActor services
struct MyTool: Tool {
    let modelContext: ModelContext
    var name: String { "my_tool" }
    var description: String { "What this tool does" }

    func call(arguments: MyToolInput) async throws -> String {
        // Implementation
    }
}
```

3. Register tool in AIService (future work)

### Accessing SwiftData

```swift
// In a view
@Environment(\.modelContext) private var modelContext
@Query(sort: \Email.date, order: .reverse) private var emails: [Email]

// Insert
let email = Email(...)
modelContext.insert(email)

// Delete
modelContext.delete(email)

// Fetch with descriptor
var descriptor = FetchDescriptor<Email>()
descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
descriptor.fetchLimit = 50
let results = try modelContext.fetch(descriptor)
```

### Email Context in AI

When a user selects an email in `MailSplitView`, the context flows:
1. `MailSplitView` updates `selectedEmail` state
2. `.onChange(of: selectedEmail)` updates `tabManager.selectedEmail`
3. `MainWindow` passes `tabManager.selectedEmail` to `AISidebarView`
4. `AISidebarView` calls `aiService.setEmailContext(email)`
5. AI responses now include email context automatically

## Troubleshooting

### Foundation Models Not Available
- Check macOS version (26.0+ required)
- Use `SystemLanguageModel.default.availability` to check
- Handle `.notAvailable` state gracefully in UI

### SwiftMail Type Conflicts
- Always fully qualify SwiftMail types: `SwiftMail.IMAPServer`
- Foundation Models also defines some networking types

### Actor Isolation Errors
- Mark tools and services with `@MainActor` if they access DraftService
- Use `Task { @MainActor in ... }` for one-off main actor calls
- Background sync should NOT use `@MainActor`

### Build Errors with @Generable
- Only use types that conform to `Generable` protocol
- Basic types: String, Int, Bool, Double, Arrays
- Avoid: Date (use Int for relative dates), UUID (use String)

## Liquid Glass Resources

### Official Apple Documentation
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [glassBackgroundEffect Documentation](https://developer.apple.com/documentation/swiftui/view/glassbackgroundeffect(in:displaymode:))
- [GlassButtonStyle Documentation](https://developer.apple.com/documentation/swiftui/glassbuttonstyle)
- [Build a SwiftUI app with the new design - WWDC25 Session 323](https://developer.apple.com/videos/play/wwdc2025/323/)

### Community Tutorials & Articles
- [Designing custom UI with Liquid Glass on iOS 26 - Donny Wals](https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/)
- [Grouping Liquid Glass components using glassEffectUnion - Donny Wals](https://www.donnywals.com/grouping-liquid-glass-components-using-glasseffectunion-on-ios-26/)
- [Glassifying custom SwiftUI views - Swift with Majid](https://swiftwithmajid.com/2025/07/16/glassifying-custom-swiftui-views/)
- [Presenting Liquid Glass sheets in SwiftUI on iOS 26](https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI/)
- [Liquid Glass sheets with NavigationStack and Form](https://nilcoalescing.com/blog/LiquidGlassSheetsWithNavigationStackAndForm/)
- [Understanding GlassEffectContainer in iOS 26](https://dev.to/arshtechpro/understanding-glasseffectcontainer-in-ios-26-2n8p)
- [Transforming Glass Views with glassEffectID - SerialCoder.dev](https://serialcoder.dev/text-tutorials/swiftui/transforming-glass-views-with-the-glasseffectid-modifier-in-swiftui/)
- [How to morph liquid glass view transition - Swift Discovery](https://onmyway133.com/posts/how-to-morph-liquid-glass-view-transition/)
- [Morphing glass effect elements with glassEffectID - Create with Swift](https://www.createwithswift.com/morphing-glass-effect-elements-into-one-another-with-glasseffectid/)
- [Glass Options in iOS 26: Clear vs Regular - Livsy Code](https://livsycode.com/swiftui/glass-options-in-ios-26-clear-vs-regular-frosted-glass/)
- [Liquid Glass in SwiftUI: glassEffect and glass buttons - Jorgemrht](https://jorgemrht.dev/2025/09/17/liquid-glass-glassEffect-buttons)
- [Grow on iOS 26 - Liquid Glass Adaptation](https://fatbobman.com/en/posts/grow-on-ios26)
- [Adopting Liquid Glass: Experiences and Pitfalls](https://juniperphoton.substack.com/p/adopting-liquid-glass-experiences)

### Sample Code & References
- [LiquidGlassReference - Comprehensive Swift/SwiftUI Reference](https://github.com/conorluddy/LiquidGlassReference)
- [LiquidGlassSwiftUI - Sample App](https://github.com/mertozseven/LiquidGlassSwiftUI)
- [dm-swift-swiftui-liquid-glass - Component Library](https://github.com/dambertmunoz/dm-swift-swiftui-liquid-glass)
- [LiquidGlassCheatsheet](https://github.com/GonzaloFuentes28/LiquidGlassCheatsheet)
