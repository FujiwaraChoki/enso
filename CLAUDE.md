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

**Core Principle: Use Standard Components First**

Standard SwiftUI components automatically adopt Liquid Glass when building with the latest SDKs. This includes:
- Bars (toolbars, tab bars, navigation bars)
- Sheets and popovers
- Controls (buttons, toggles, sliders)
- Split views and sidebars

**Remove custom styling** and let the system handle appearances. Custom backgrounds and effects can interfere with Liquid Glass.

#### When to Use `.glassEffect()`

Use `.glassEffect(_:in:)` modifier ONLY for custom components that need Liquid Glass appearance:

```swift
// For custom views only
Text("Custom Label")
    .padding()
    .glassEffect()  // Applies capsule shape by default

// With custom shape
Text("Custom Label")
    .padding()
    .glassEffect(in: .rect(cornerRadius: 16.0))

// Interactive (responds to touch/hover)
Button("Action") { }
    .glassEffect(.regular.interactive())
```

#### GlassEffectContainer

Use `GlassEffectContainer` when multiple custom glass elements need to:
- Render together for better performance
- Morph and blend into each other during animations

```swift
GlassEffectContainer(spacing: 40.0) {
    HStack(spacing: 40.0) {
        // Multiple glass effects can blend together
    }
}
```

#### Button Styles

SwiftUI provides native glass button styles:
- `.buttonStyle(.glass)` - Standard glass appearance
- `.buttonStyle(.glassProminent)` - Emphasized glass appearance

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
