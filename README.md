# Enso

A modern macOS email client built with SwiftUI, featuring on-device AI assistance and Liquid Glass design.

## Features

- **Multi-account Support**: Connect multiple IMAP/SMTP email accounts
- **On-device AI**: Powered by Apple's Foundation Models for privacy-focused email assistance
- **Liquid Glass Design**: Beautiful, modern UI with Instrument Serif typography
- **Tab Interface**: Browser-style tabs for managing multiple email views
- **Real-time Sync**: IMAP IDLE support for instant email notifications
- **Secure Storage**: All credentials stored in macOS Keychain

## Requirements

- macOS 26.1 or later
- Xcode 16.0 or later

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/FujiwaraChoki/Enso.git
   cd Enso
   ```

2. Open the project in Xcode:
   ```bash
   open Enso.xcodeproj
   ```

3. Build and run (Cmd+R)

### Building from Command Line

```bash
# Build
xcodebuild -project Enso.xcodeproj -scheme Enso -configuration Debug build

# Build and run
xcodebuild -project Enso.xcodeproj -scheme Enso -configuration Debug build && open build/Debug/Enso.app
```

## Documentation

- [Architecture & Development Guide](CLAUDE.md) - Detailed technical documentation
- [Contributing Guidelines](CONTRIBUTING.md) - How to contribute to the project
- [Changelog](CHANGELOG.md) - Version history and changes

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md) before submitting pull requests.

## Security

If you discover a security vulnerability, please email [sami@samihindi.com] instead of opening a public issue. See [SECURITY.md](SECURITY.md) for details.

## License

Source Available - Non-Commercial Use Only

See [LICENSE](LICENSE) for details.

## Contact

For questions, suggestions, or commercial licensing inquiries, contact [sami@samihindi.com]
