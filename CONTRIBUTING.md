# Contributing to Enso

Thank you for your interest in contributing to Enso! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

### Reporting Bugs

Before creating a bug report, please check the existing issues to see if the problem has already been reported.

When creating a bug report, please include:
- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Screenshots (if applicable)
- Your macOS version
- Xcode version
- Any relevant error messages or logs

### Suggesting Features

Feature suggestions are welcome! Please open an issue with:
- A clear description of the feature
- Use cases and examples
- Any potential implementation considerations

### Pull Requests

1. **Fork the repository** and create a branch from `main`
2. **Make your changes** following the project's coding standards
3. **Write or update tests** for your changes
4. **Update documentation** if needed
5. **Ensure all tests pass** before submitting
6. **Submit a pull request** with a clear description of your changes

### Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/FujiwaraChoki/Enso.git
   cd Enso
   ```

2. Open the project in Xcode:
   ```bash
   open Enso.xcodeproj
   ```

3. Build and run the project (Cmd+R)

### Coding Standards

- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Maintain consistency with existing code style
- Write self-documenting code with clear variable and function names
- Add comments for complex logic

### Testing

- Write unit tests for new functionality
- Ensure existing tests continue to pass
- Test on the minimum supported macOS version (26.1+)

### Commit Messages

Write clear, descriptive commit messages:
- Use the imperative mood ("Add feature" not "Added feature")
- Keep the first line under 72 characters
- Reference issue numbers when applicable

Example:
```
Add dark mode support for email list view

Fixes #123
```

### License

By contributing, you agree that your contributions will be licensed under the same license as the project (see [LICENSE](LICENSE) for details).

## Questions?

If you have questions about contributing, please open an issue with the `question` label.
