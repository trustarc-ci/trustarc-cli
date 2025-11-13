# TrustArc SDK Diagnostic Tool

## Overview

The TrustArc SDK Diagnostic Tool is an intelligent analyzer that examines your mobile project to ensure correct TrustArc SDK integration. It provides automated scanning, issue detection, and an interactive Q&A interface to help developers troubleshoot integration problems.

## Features

### 1. Automated Project Scanning
- **Multi-Platform Support**: Android, iOS, React Native, and Flutter
- **Dependency Detection**: Verifies SDK is properly added to project dependencies
- **Configuration Validation**: Checks for required permissions and settings
- **Code Analysis**: Scans source files for SDK usage patterns
- **Pattern Matching**: Detects common integration antipatterns

### 2. Comprehensive Reporting
- **Severity Levels**: Issues categorized as Error, Warning, Info, or Success
- **Score System**: 0-100 score based on integration quality
- **File References**: Direct links to problematic files and line numbers
- **Actionable Suggestions**: Specific fix recommendations for each issue

### 3. Interactive Q&A Assistant
- **Knowledge Base**: Pre-loaded with common SDK integration questions
- **Context-Aware**: Provides answers tailored to your diagnostic results
- **Multi-Topic Coverage**: Initialization, consent dialogs, data retrieval, WebView integration, listeners, and errors

## Usage

### Via CLI Menu

1. Run the TrustArc CLI installer:
   ```bash
   sh -c "$(curl -fsSL https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh)"
   ```

2. Select option **3) Diagnose project** from the main menu

3. Enter your project path when prompted

4. Review the diagnostic report

5. Optionally enter Q&A mode to ask follow-up questions

### Standalone Usage

#### Run Diagnostic Only
```bash
python3 lib/diagnose.py /path/to/your/project
```

#### Generate JSON Report
```bash
python3 lib/diagnose.py /path/to/your/project --json
```

#### Start Q&A Assistant
```bash
python3 lib/diagnose_qa.py
```

#### Q&A with Diagnostic Context
```bash
# First, generate a diagnostic report
python3 lib/diagnose.py /path/to/project --json > report.json

# Then start Q&A with context
python3 lib/diagnose_qa.py report.json
```

## What It Checks

### Android Projects
- ✓ TrustArc SDK dependency in build.gradle/build.gradle.kts
- ✓ SDK version detection
- ✓ Required permissions in AndroidManifest.xml (INTERNET, ACCESS_NETWORK_STATE)
- ✓ SDK import statements in Kotlin/Java files
- ✓ TrustArc instance creation with correct SdkMode
- ✓ Proper initialization flow (constructor → configuration → start())
- ✓ Debug logging configuration
- ✓ Consent listener registration
- ✓ Method call ordering (start before openCM)

### iOS Projects
- ✓ TrustArc SDK in Package.swift (SPM) or Podfile (CocoaPods)
- ✓ SDK import statements in Swift files
- ✓ TrustArc instance creation
- ✓ Proper initialization with start() call

### React Native Projects
- ✓ TrustArc package in package.json
- ✓ SDK usage in JavaScript/TypeScript files
- ✓ Import statements

### Flutter Projects
- ✓ TrustArc package in pubspec.yaml
- ✓ SDK usage in Dart files
- ✓ Import statements

## Sample Output

```
================================================================================
TrustArc SDK Diagnostic Report
================================================================================

Platform: android
Project: /Users/demo/MyAndroidApp
Score: 70/100

✓ SUCCESSES:
--------------------------------------------------------------------------------
  TrustArc SDK found (version 2025.09.2)
    File: /Users/demo/MyAndroidApp/app/build.gradle.kts

✗ ERRORS:
--------------------------------------------------------------------------------
  [Permissions] Missing required permission: INTERNET
    → Add: <uses-permission android:name="android.permission.INTERNET" />

  [Initialization] TrustArc instance created but start() never called
    File: /Users/demo/MyAndroidApp/app/src/main/java/com/example/MainActivity.kt
    → Call trustArc.start(domainName = "your.domain")

⚠ WARNINGS:
--------------------------------------------------------------------------------
  [Permissions] Missing recommended permission: ACCESS_NETWORK_STATE
    → Add: <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

ℹ INFO:
--------------------------------------------------------------------------------
  [Configuration] Consider enabling debug logging for development
    File: /Users/demo/MyAndroidApp/app/src/main/java/com/example/MainActivity.kt
    → Add: trustArc.enableDebugLog(true)

================================================================================
```

## Q&A Assistant Topics

The interactive Q&A assistant can answer questions about:

### Initialization
- How to initialize the SDK
- Why SDK isn't initializing
- Difference between SDK modes (Standard vs IabTCFv_2_2)

### Consent Dialog
- How to show consent dialog
- Why dialog isn't appearing
- Auto-showing dialog on first launch

### Data Retrieval
- Getting user consent data
- Retrieving IAB TCF strings
- Accessing Google consents
- Checking specific consent values

### WebView Integration
- Injecting consent scripts into WebView
- Synchronizing native and web consent
- Required WebView settings

### Listeners & Callbacks
- Listening for consent changes
- SDK initialization callbacks
- Handling consent updates

### Common Errors
- Troubleshooting initialization errors
- Network/timeout issues
- Permission problems
- Dependency resolution errors

## Example Q&A Session

```
================================================================================
TrustArc SDK Q&A Assistant
================================================================================

Ask questions about TrustArc SDK integration (or 'quit' to exit)
Example questions:
  - How do I initialize the SDK?
  - Why is my consent dialog not showing?
  - How do I get consent data?

✓ Loaded diagnostic report (Platform: android)

Your question: How do I initialize the SDK?

--------------------------------------------------------------------------------

[INITIALIZATION] How do I initialize the TrustArc SDK?

The initialization process varies by platform:

ANDROID (Kotlin):
```kotlin
val trustArc = TrustArc(context, SdkMode.Standard)
trustArc.enableDebugLog(true)  // Optional, for debugging
trustArc.start(domainName = "your.domain.com")
```

iOS (Swift):
```swift
let trustArc = TrustArc(context: context, sdkMode: .standard)
trustArc.enableDebugLog(true)  // Optional
trustArc.start(domainName: "your.domain.com")
```

[Additional examples for React Native and Flutter...]

--------------------------------------------------------------------------------

Your question: quit

Goodbye!
```

## Requirements

- **Python 3.6+**: Required to run diagnostic scripts
- **Project Access**: Read access to project files and directories

## Integration Patterns Checked

The diagnostic tool validates against established TrustArc SDK integration patterns:

### Initialization Flow
1. Create TrustArc instance with context and SDK mode
2. Configure optional settings (debug logging, GDPR detection)
3. Register listeners (initialization, consent changes)
4. Call start() with domain name
5. Wait for initialization before using SDK methods

### Method Order Validation
- Ensures `start()` is called after constructor
- Warns if `openCM()` called before `start()`
- Checks listener registration timing

### Configuration Validation
- Required permissions present
- Correct SDK mode for use case
- Proper WebView settings for web integration

## Scoring System

The diagnostic tool assigns a score from 0-100 based on:

- **SDK Found**: +30 points if dependency is properly configured
- **No Errors**: -20 points per error found
- **No Warnings**: -10 points per warning found
- **Successful Checks**: Positive indicators increase score

**Score Interpretation:**
- **90-100**: Excellent - SDK properly integrated
- **70-89**: Good - Minor improvements recommended
- **50-69**: Fair - Some issues need attention
- **0-49**: Poor - Significant integration problems

## Exit Codes

When run standalone, the diagnostic script exits with:
- **0**: Success (score ≥ 70)
- **1**: Issues found (score < 70)

This allows integration with CI/CD pipelines:

```bash
#!/bin/bash
python3 lib/diagnose.py ./my-app || {
    echo "SDK integration has issues"
    exit 1
}
```

## Limitations

- **Static Analysis Only**: Cannot detect runtime issues
- **Pattern-Based**: May miss non-standard implementations
- **No Network Testing**: Doesn't validate domain configuration with TrustArc servers
- **Limited Context**: Q&A assistant uses knowledge base, not true AI reasoning

## Future Enhancements

Potential improvements for future versions:

- [ ] Network connectivity testing to TrustArc servers
- [ ] Domain validation against TrustArc dashboard
- [ ] Runtime SDK behavior testing
- [ ] Integration with CI/CD systems (GitHub Actions, Jenkins)
- [ ] Custom rule definitions
- [ ] HTML report generation
- [ ] Fix automation (auto-apply suggested changes)
- [ ] Version compatibility checking
- [ ] Performance analysis

## Contributing

To extend the diagnostic tool:

1. **Add New Checks**: Edit `lib/diagnose.py` and add validation methods to platform-specific classes
2. **Expand Knowledge Base**: Update `KNOWLEDGE_BASE` dict in `lib/diagnose_qa.py`
3. **Support New Platforms**: Create new diagnostic class inheriting base patterns

## Troubleshooting

### "Python 3 is required"
Install Python 3:
- macOS: `brew install python3`
- Ubuntu/Debian: `sudo apt-get install python3`
- Windows: Download from python.org

### "Diagnostic script not found"
The CLI automatically downloads scripts from GitHub. Ensure:
- Internet connectivity
- GitHub repository is accessible
- curl or wget is installed

### Incorrect Results
If diagnostic reports incorrect findings:
1. Enable verbose mode (if available)
2. Check file permissions (scripts need read access)
3. Verify project directory structure
4. Report issue with project details

## License

Part of the TrustArc CLI toolkit. See main LICENSE file for details.

## Support

For issues or questions:
- GitHub Issues: [trustarc-ci/trustarc-cli](https://github.com/trustarc-ci/trustarc-cli/issues)
- Documentation: [TrustArc Developer Docs](https://developer.trustarc.com)
