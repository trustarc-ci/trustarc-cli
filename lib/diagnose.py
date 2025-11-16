#!/usr/bin/env python3
"""
TrustArc SDK Diagnostic Tool
Analyzes projects to ensure correct SDK integration and usage patterns
"""

import os
import re
import json
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, field
from enum import Enum


class Severity(Enum):
    """Issue severity levels"""
    ERROR = "error"
    WARNING = "warning"
    INFO = "info"
    SUCCESS = "success"


class Platform(Enum):
    """Supported platforms"""
    ANDROID = "android"
    IOS = "ios"
    REACT_NATIVE = "react-native"
    FLUTTER = "flutter"
    UNKNOWN = "unknown"


@dataclass
class Issue:
    """Represents a diagnostic issue"""
    severity: Severity
    category: str
    message: str
    file_path: Optional[str] = None
    line_number: Optional[int] = None
    suggestion: Optional[str] = None

    def to_dict(self):
        return {
            'severity': self.severity.value,
            'category': self.category,
            'message': self.message,
            'file_path': self.file_path,
            'line_number': self.line_number,
            'suggestion': self.suggestion
        }


@dataclass
class DiagnosticReport:
    """Complete diagnostic report"""
    platform: Platform
    project_path: str
    issues: List[Issue]
    sdk_found: bool
    initialization_found: bool
    score: int  # 0-100
    ai_questions: List[Dict[str, str]] = field(default_factory=list)
    platform_neurolink: Optional[str] = None
    guide_insights: List[Dict[str, str]] = field(default_factory=list)

    def to_dict(self):
        return {
            'platform': self.platform.value,
            'project_path': self.project_path,
            'sdk_found': self.sdk_found,
            'initialization_found': self.initialization_found,
            'score': self.score,
            'issues': [issue.to_dict() for issue in self.issues],
            'ai_questions': self.ai_questions,
            'platform_neurolink': self.platform_neurolink,
            'guide_insights': self.guide_insights
        }


class AIReasoner:
    """Lightweight AI helper to craft contextual questions and insights."""

    CATEGORY_TEMPLATES = {
        "Dependency": "How is the TrustArc SDK dependency declared in your {platform} build setup?",
        "Initialization": "Where do you initialize the TrustArc SDK within the {platform} lifecycle?",
        "Permissions": "Are the required permissions enabled for TrustArc network calls on {platform}?",
        "Configuration": "How is the TrustArc domain or configuration persisted across {platform} builds?",
        "Implementation": "Does the TrustArc API usage map to the intended user journey on {platform}?",
        "Architecture": "Does the project structure surface a stable entry point for TrustArc flows on {platform}?",
        "Platform": "Is the detected platform ({platform}) aligned with the project you selected?",
    }

    PLATFORM_BEHAVIOR = {
        Platform.ANDROID: "Android checks trace Gradle dependencies, manifest permissions, and lifecycle calls like start() and openCM().",
        Platform.IOS: "iOS diagnostics observe CocoaPods dependency wiring, AppDelegate hooks, and Swift/Obj-C consent manager usage.",
        Platform.REACT_NATIVE: "React Native logic inspects metro configs, JS bridge calls, and native module registrations for TrustArc.",
        Platform.FLUTTER: "Flutter scanning follows pubspec dependencies, Dart channel wiring, and platform channel invocations.",
        Platform.UNKNOWN: "No known platform signature was detected; heuristics could not map the project to Android, iOS, React Native, or Flutter.",
    }

    SEVERITY_PRIORITY = {
        Severity.ERROR: 0,
        Severity.WARNING: 1,
        Severity.INFO: 2,
        Severity.SUCCESS: 3,
    }

    def __init__(self, report: DiagnosticReport):
        self.report = report
        self.guide_entries = GuideKnowledge.get_entries(report.platform)

    def generate_context_questions(self) -> List[Dict[str, str]]:
        """Create context-aware Q&A prompts based on detected issues."""
        prioritized = sorted(self.report.issues, key=self._issue_priority)
        qa_pairs: List[Dict[str, str]] = []

        for issue in prioritized:
            if issue.severity not in (Severity.ERROR, Severity.WARNING):
                continue

            qa_pairs.append({
                "question": self._build_question_prompt(issue),
                "answer": self._build_answer_prompt(issue)
            })

            if len(qa_pairs) >= 5:
                break

        if not qa_pairs:
            qa_pairs.append(self._default_question())

        return qa_pairs

    def generate_platform_neurolink(self) -> str:
        """Summarize platform behaviors and SDK usage in a concise neurolink."""
        platform_blurb = self.PLATFORM_BEHAVIOR.get(self.report.platform, self.PLATFORM_BEHAVIOR[Platform.UNKNOWN])
        errors = len([i for i in self.report.issues if i.severity == Severity.ERROR])
        warnings = len([i for i in self.report.issues if i.severity == Severity.WARNING])
        infos = len([i for i in self.report.issues if i.severity == Severity.INFO])
        categories = sorted({issue.category for issue in self.report.issues})

        status_bits = [
            "SDK dependency detected" if self.report.sdk_found else "SDK dependency not observed",
            "Initialization sequence confirmed" if self.report.initialization_found else "Initialization entry point missing",
            f"Issue categories touched: {', '.join(categories)}" if categories else "No categorized issues recorded",
            f"Signal strength → {errors} errors / {warnings} warnings / {infos} info items",
        ]

        doc_hint = GuideKnowledge.get_hint(self.report.platform, "Guide Summary")
        if doc_hint:
            status_bits.append(f"Guide v3.1: {doc_hint.rstrip('.')}")

        neurolink = f"{platform_blurb} Neurolink synthesis: " + "; ".join(status_bits) + "."
        return neurolink

    def _issue_priority(self, issue: Issue) -> int:
        return self.SEVERITY_PRIORITY.get(issue.severity, 99)

    def _build_question_prompt(self, issue: Issue) -> str:
        template = self.CATEGORY_TEMPLATES.get(
            issue.category,
            "What adjustments are required around {category} to resolve \"{message}\" on {platform}?"
        )
        return template.format(
            platform=self.report.platform.value,
            category=issue.category.lower(),
            message=issue.message
        )

    def _build_answer_prompt(self, issue: Issue) -> str:
        context_bits = [f"{issue.severity.value.upper()} detected: {issue.message}"]
        if issue.file_path:
            context_bits.append(f"File: {issue.file_path}")
        if issue.line_number:
            context_bits.append(f"Line: {issue.line_number}")
        if issue.suggestion:
            context_bits.append(f"Suggested action: {issue.suggestion}")
        guide_hint = GuideKnowledge.get_hint(self.report.platform, issue.category)
        if guide_hint:
            context_bits.append(f"Guide v3.1 hint: {guide_hint.rstrip('.')}")
        return "AI reasoning → " + " | ".join(context_bits)

    def _default_question(self) -> Dict[str, str]:
        question = f"Where in the {self.report.platform.value} project lifecycle should the TrustArc SDK reasoning live?"
        guide_hint = GuideKnowledge.get_hint(self.report.platform, "Guide Summary")
        if guide_hint:
            answer_hint = f"Guide v3.1 hint: {guide_hint.rstrip('.')}"
        else:
            answer_hint = "Guide v3.1 hint: Ensure you're following the official onboarding steps for your platform."
        answer = (
            "AI reasoning → The diagnostic run did not surface blocking issues, so double-check that "
            "TrustArc initialization aligns with your first screen or app delegate to keep consent flows predictable. "
            f"{answer_hint}"
        )
        return {"question": question, "answer": answer}


class GuideKnowledge:
    """Embeds curated context from the TrustArc Mobile App Consent Integration Guide v3.1."""

    GUIDE_ENTRIES = {
        Platform.ANDROID: [
            ("Guide Summary", "Guide v3.1 describes onboarding via TrustArc support, authenticating to the GitHub Maven repo "
             "at https://maven.pkg.github.com/trustarc/trustarc-mobile-consent, and keeping the personal access token secure."),
            ("Dependencies", "Add com.trustarc:trustarc-consent-sdk:2025.04.2 plus the AndroidX stack "
             "(core-ktx, appcompat, constraintlayout, webkit, lifecycle, activity, material, retrofit + gson)."),
            ("Initialization & Consent", "Instantiate TrustArc(context, sdkMode, onGoogleConsent) then call start(domainName, onConsent). "
             "Use getStoredConsentData or getConsentsByCategory (added in 2025.07.1) which emits 2/1/0 values and suffixes -0…-3 per category."),
            ("Google Consent Mode", "Wire Firebase + Google's consent delegate so ads_storage, analytics_storage, ad_personalization, "
             "and ad_user_data signals match the UI choices surfaced by the TrustArc SDK.")
        ],
        Platform.IOS: [
            ("Guide Summary", "Guide v3.1 walks through pulling trustarc-mobile-consent.git into Xcode via Swift Package Manager "
             "using the release branch or tags such as v2025.04.02 and verifying the signed package."),
            ("Dependencies", "Requirements call for Xcode 16+, iOS 12+, Swift 6 (source-compatible with Swift 5), "
             "and authenticated GitHub package access (username trustarc + token)."),
            ("Initialization & Consent", "Mark UI-facing classes with @MainActor, set TrustArc.sharedInstance delegates, "
             "configure domain + mode, and call start(...) to optionally show the consent UI. "
             "Handle TAConsentViewControllerDelegate.didReceiveConsentData and leverage getConsentDataByCategory "
             "where 2/1/0 encode required/consented/rejected domains."),
            ("App Tracking", "Populate NSUserTrackingUsageDescription and, when using ATT, request tracking permission after "
             "TrustArc signals shouldShowConsentUI.")
        ],
        Platform.REACT_NATIVE: [
            ("Guide Summary", "Guide v3.1 directs you to export TRUSTARC_TOKEN, add .npmrc that routes @trustarc scope to GitHub Packages, "
             "and depend on @trustarc/trustarc-react-native-consent-sdk (React Native 0.60+)."),
            ("Project Wiring", "Expo builds must add extraMavenRepos with the GitHub URL + credentials and provide "
             "NSUserTrackingUsageDescription for iOS; bare projects install pods in ios/."),
            ("Initialization & Consent", "Instantiate TrustArcSdk, call initialize/start with the MAC domain, and listen for "
             "onSdkInitFinish and onConsentChanges via NativeEventEmitter. Parse getStoredConsentData JSON to split "
             "domains by suffix (-0 to -3) and apply tracking."),
        ],
        Platform.FLUTTER: [
            ("Guide Summary", "Guide v3.1 instructs exporting TRUSTARC_TOKEN, adding flutter_trustarc_mobile_consent_sdk "
             "from the trustarc-mobile-consent.git (path flutter, ref release or tagged), and running flutter pub get."),
            ("Initialization & Consent", "Instantiate FlutterTrustarcMobileConsentSdk, call initialize + start, subscribe to "
             "onSdkInitFinish/onConsentChanges/onGoogleConsentChanges, and process getStoredConsentData or "
             "getConsentDataByCategory (since 2025.07.1) where suffixes signal required/functional/advertising/custom buckets."),
            ("UI Hooks", "Expose a UI control such as an ElevatedButton to openCM(domain, ''), and surface toast/log output "
             "when consent or Google consent events fire."),
        ]
    }

    CATEGORY_TOPIC = {
        "Dependency": "Dependencies",
        "Permissions": "Dependencies",
        "Initialization": "Initialization & Consent",
        "Implementation": "Initialization & Consent",
        "Configuration": "Initialization & Consent",
        "Architecture": "Guide Summary",
        "Platform": "Guide Summary",
    }

    @classmethod
    def get_entries(cls, platform: Platform) -> List[Tuple[str, str]]:
        return cls.GUIDE_ENTRIES.get(platform, [])

    @classmethod
    def get_hint(cls, platform: Platform, category: str) -> Optional[str]:
        entries = cls.get_entries(platform)
        if not entries:
            return None

        title = cls.CATEGORY_TOPIC.get(category, "Guide Summary")
        for entry_title, detail in entries:
            if entry_title == title:
                return detail

        # Fall back to summary if nothing matches
        for entry_title, detail in entries:
            if "Summary" in entry_title:
                return detail

        return entries[0][1]

class AndroidDiagnostic:
    """Android-specific diagnostic checks"""

    REQUIRED_PATTERNS = {
        'sdk_import': r'import\s+com\.truste\.androidmobileconsentsdk\.TrustArc',
        'sdk_constructor': r'TrustArc\s*\(',  # Look for constructor call
        'sdkmode_usage': r'SdkMode\.',  # Separate check for SdkMode usage
        'sdk_start': r'\.start\s*\(',
    }

    RECOMMENDED_PATTERNS = {
        'enable_debug': r'\.enableDebugLog\s*\(',
        'add_consent_listener': r'\.addConsentListener\s*\{',
        'open_cm': r'\.openCM\s*\(',
    }

    ANTIPATTERNS = {
        'start_before_constructor': 'Calling start() without TrustArc instance',
        'open_cm_before_start': 'Calling openCM() before start()',
        'missing_internet_permission': 'Missing INTERNET permission',
    }

    def __init__(self, project_path: str):
        self.project_path = Path(project_path)
        self.issues: List[Issue] = []

    def scan(self) -> List[Issue]:
        """Run all Android diagnostic checks"""
        self.check_gradle_dependency()
        self.check_manifest_permissions()
        self.check_kotlin_java_files()
        self.check_initialization_flow()
        return self.issues

    def check_gradle_dependency(self):
        """Check if TrustArc SDK is in gradle dependencies"""
        gradle_files = list(self.project_path.rglob("build.gradle*"))
        toml_files = list(self.project_path.rglob("libs.versions.toml"))

        found = False
        version = None

        # Check traditional gradle files
        for gradle_file in gradle_files:
            try:
                content = gradle_file.read_text()
                if 'com.trustarc:trustarc-consent-sdk' in content or 'trustarc.consent.sdk' in content:
                    found = True

                    # Check version
                    version_match = re.search(r'trustarc-consent-sdk["\']?\s*:\s*["\']?(\d+\.\d+\.\d+)', content)
                    if version_match:
                        version = version_match.group(1)

                    if version:
                        self.issues.append(Issue(
                            severity=Severity.SUCCESS,
                            category="Dependency",
                            message=f"TrustArc SDK found (version {version})",
                            file_path=str(gradle_file)
                        ))
                    else:
                        self.issues.append(Issue(
                            severity=Severity.SUCCESS,
                            category="Dependency",
                            message="TrustArc SDK found (using version catalog)",
                            file_path=str(gradle_file)
                        ))
                    break
            except Exception:
                continue

        # Check Gradle version catalogs (libs.versions.toml)
        if not found:
            for toml_file in toml_files:
                try:
                    content = toml_file.read_text()
                    if 'trustarc-consent-sdk' in content or 'trustarcConsentSdk' in content:
                        found = True

                        # Try to extract version from toml
                        version_match = re.search(r'trustarcConsentSdk\s*=\s*"(\d+\.\d+\.\d+)"', content)
                        if version_match:
                            version = version_match.group(1)

                        if version:
                            self.issues.append(Issue(
                                severity=Severity.SUCCESS,
                                category="Dependency",
                                message=f"TrustArc SDK found in version catalog (version {version})",
                                file_path=str(toml_file)
                            ))
                        else:
                            self.issues.append(Issue(
                                severity=Severity.SUCCESS,
                                category="Dependency",
                                message="TrustArc SDK found in version catalog",
                                file_path=str(toml_file)
                            ))
                        break
                except Exception:
                    continue

        if not found:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Dependency",
                message="TrustArc SDK dependency not found in gradle files",
                suggestion="Add: implementation(\"com.trustarc:trustarc-consent-sdk:VERSION\") or add to libs.versions.toml"
            ))

    def check_manifest_permissions(self):
        """Check AndroidManifest.xml for required permissions"""
        manifest_files = list(self.project_path.rglob("AndroidManifest.xml"))

        required_permissions = {
            'android.permission.INTERNET': False,
            'android.permission.ACCESS_NETWORK_STATE': False,
        }

        for manifest in manifest_files:
            try:
                content = manifest.read_text()
                for perm in required_permissions:
                    if perm in content:
                        required_permissions[perm] = True
            except Exception:
                continue

        if not required_permissions['android.permission.INTERNET']:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Permissions",
                message="Missing required permission: INTERNET",
                suggestion='Add: <uses-permission android:name="android.permission.INTERNET" />'
            ))

        if not required_permissions['android.permission.ACCESS_NETWORK_STATE']:
            self.issues.append(Issue(
                severity=Severity.WARNING,
                category="Permissions",
                message="Missing recommended permission: ACCESS_NETWORK_STATE",
                suggestion='Add: <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />'
            ))

    def check_kotlin_java_files(self):
        """Check Kotlin/Java files for SDK usage"""
        code_files = list(self.project_path.rglob("*.kt")) + list(self.project_path.rglob("*.java"))

        # Collect all SDK-related files
        sdk_files = []
        di_files = []  # Hilt/Dagger DI files
        application_files = []  # Application class files
        manager_files = []  # ConsentManager or similar wrapper files

        for code_file in code_files:
            try:
                content = code_file.read_text()

                # Check for TrustArc SDK usage
                if 'TrustArc' in content and 'com.truste.androidmobileconsentsdk' in content:
                    sdk_files.append((code_file, content))

                # Check for DI patterns
                if any(anno in content for anno in ['@Module', '@Provides', '@Singleton', '@Inject', '@HiltAndroidApp', '@AndroidEntryPoint']):
                    di_files.append((code_file, content))

                # Check for Application class
                if re.search(r'class\s+\w+\s*:\s*Application\(\)', content) or \
                   re.search(r'class\s+\w+\s+extends\s+Application', content):
                    application_files.append((code_file, content))

                # Check for ConsentManager or similar wrappers
                if re.search(r'(ConsentManager|TrustArcManager|SdkManager)', content):
                    manager_files.append((code_file, content))

            except Exception:
                continue

        if not sdk_files:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Implementation",
                message="No TrustArc SDK usage found in Kotlin/Java files",
                suggestion="Import and initialize TrustArc SDK"
            ))
            return

        # Analyze the project architecture
        self.analyze_initialization_architecture(sdk_files, di_files, application_files, manager_files)

    def analyze_initialization_architecture(self, sdk_files, di_files, application_files, manager_files):
        """Analyze the overall initialization architecture"""

        # Check if using Dependency Injection
        using_di = len(di_files) > 0

        # Find where TrustArc constructor is called
        constructor_locations = []
        start_locations = []

        for file_path, content in sdk_files:
            # Check for constructor (must have both TrustArc( and SdkMode)
            if re.search(self.REQUIRED_PATTERNS['sdk_constructor'], content) and \
               re.search(self.REQUIRED_PATTERNS['sdkmode_usage'], content):
                constructor_locations.append((file_path, content))
            if re.search(self.REQUIRED_PATTERNS['sdk_start'], content):
                start_locations.append((file_path, content))

        if using_di:
            # DI-based architecture
            self.check_di_architecture(constructor_locations, start_locations, di_files, application_files, manager_files, sdk_files)
        else:
            # Traditional direct initialization
            self.check_traditional_architecture(constructor_locations, start_locations, sdk_files)

    def check_di_architecture(self, constructor_locations, start_locations, di_files, application_files, manager_files, sdk_files):
        """Check DI-based initialization (Hilt/Dagger)"""

        # Check if constructor is in @Provides method (good pattern)
        has_provides_trustarc = False
        for file_path, content in di_files:
            if re.search(r'@Provides.*?TrustArc', content, re.DOTALL):
                has_provides_trustarc = True
                self.issues.append(Issue(
                    severity=Severity.SUCCESS,
                    category="Architecture",
                    message="TrustArc provided via Dependency Injection",
                    file_path=str(file_path)
                ))
                break

        # Check if there's a wrapper/manager class
        has_manager_with_start = False
        for file_path, content in manager_files:
            if re.search(r'\.start\s*\(', content):
                has_manager_with_start = True

                # Check if manager is injected
                if '@Inject' in content:
                    self.issues.append(Issue(
                        severity=Severity.SUCCESS,
                        category="Architecture",
                        message="Initialization encapsulated in injected manager class",
                        file_path=str(file_path)
                    ))
                break

        # Check if Application class initializes the SDK
        has_application_init = False
        for file_path, content in application_files:
            if '@HiltAndroidApp' in content:
                # Look for initialization call
                if re.search(r'(initialize|init|start)', content, re.IGNORECASE):
                    has_application_init = True
                    self.issues.append(Issue(
                        severity=Severity.SUCCESS,
                        category="Initialization",
                        message="SDK initialized in Application class",
                        file_path=str(file_path)
                    ))
                    break

        # Only report error if using DI but missing complete initialization flow
        if has_provides_trustarc and not (has_manager_with_start or has_application_init):
            # Check if start() is called anywhere
            if not start_locations:
                self.issues.append(Issue(
                    severity=Severity.ERROR,
                    category="Initialization",
                    message="TrustArc provided via DI but start() never called",
                    suggestion="Call trustArc.start(domainName) in Application class or manager"
                ))

        # Info: recommend debug logging if not found
        has_debug_log = any(re.search(r'\.enableDebugLog\s*\(', content) for _, content in sdk_files)
        if not has_debug_log and (has_manager_with_start or has_application_init):
            self.issues.append(Issue(
                severity=Severity.INFO,
                category="Configuration",
                message="Consider enabling debug logging for development",
                suggestion="Add: trustArc.enableDebugLog(true) before start()"
            ))

    def check_traditional_architecture(self, constructor_locations, start_locations, sdk_files):
        """Check traditional direct initialization (non-DI)"""

        if not constructor_locations:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Initialization",
                message="TrustArc instance never created",
                suggestion="Create instance: val trustArc = TrustArc(context, SdkMode.Standard)"
            ))
            return

        if not start_locations:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Initialization",
                message="TrustArc instance created but start() never called",
                file_path=str(constructor_locations[0][0]),
                suggestion="Call trustArc.start(domainName = \"your.domain\")"
            ))
            return

        # Check if constructor and start are in same file
        constructor_files = {str(fp) for fp, _ in constructor_locations}
        start_files = {str(fp) for fp, _ in start_locations}

        if constructor_files.intersection(start_files):
            # Same file - check order
            for file_path, content in sdk_files:
                if str(file_path) in constructor_files:
                    self.check_same_file_initialization_order(file_path, content)
        else:
            # Different files - check for singleton pattern
            self.check_cross_file_initialization(constructor_locations, start_locations)

        # Check for recommended patterns
        has_debug_log = any(re.search(r'\.enableDebugLog\s*\(', content) for _, content in sdk_files)
        if not has_debug_log:
            self.issues.append(Issue(
                severity=Severity.INFO,
                category="Configuration",
                message="Consider enabling debug logging for development",
                suggestion="Add: trustArc.enableDebugLog(true)"
            ))

    def check_same_file_initialization_order(self, file_path: Path, content: str):
        """Check initialization order in same file"""
        lines = content.split('\n')
        constructor_line = -1
        start_line = -1

        for i, line in enumerate(lines):
            if re.search(r'TrustArc\s*\(', line):
                constructor_line = i
            if re.search(r'\.start\s*\(', line) and 'trustArc' in lines[max(0, i-2):i+1].__str__().lower():
                start_line = i

        if constructor_line > 0 and start_line > 0:
            if start_line < constructor_line:
                self.issues.append(Issue(
                    severity=Severity.ERROR,
                    category="Initialization",
                    message="start() called before TrustArc constructor",
                    file_path=str(file_path),
                    line_number=start_line + 1,
                    suggestion="Ensure TrustArc instance is created before calling start()"
                ))
            else:
                self.issues.append(Issue(
                    severity=Severity.SUCCESS,
                    category="Initialization",
                    message="TrustArc properly initialized with start()",
                    file_path=str(file_path)
                ))

    def check_cross_file_initialization(self, constructor_locations, start_locations):
        """Check initialization across different files"""
        # Look for singleton pattern (TASharedInstance)
        for file_path, content in start_locations:
            if 'TASharedInstance' in content or 'getSdkInstance' in content:
                self.issues.append(Issue(
                    severity=Severity.SUCCESS,
                    category="Initialization",
                    message="Using singleton pattern for cross-activity access",
                    file_path=str(file_path)
                ))
                return

        # If no singleton pattern found, just note that initialization is split
        self.issues.append(Issue(
            severity=Severity.INFO,
            category="Architecture",
            message="TrustArc constructor and start() in different files",
            suggestion="Ensure start() is called after constructor in application flow"
        ))

    def check_initialization_flow(self):
        """Check for proper initialization flow"""
        # This method is called from scan() but actual logic is now in analyze_initialization_architecture
        pass


class iOSDiagnostic:
    """iOS-specific diagnostic checks"""

    REQUIRED_PATTERNS = {
        'sdk_import': r'import\s+trustarc_consent_sdk',  # Lowercase with underscores
        'shared_instance': r'TrustArc\.sharedInstance',  # Singleton pattern
        'set_domain': r'\.setDomain\s*\(',
        'sdk_start': r'\.start\s*\{',  # Start with closure
    }

    def __init__(self, project_path: str):
        self.project_path = Path(project_path)
        self.issues: List[Issue] = []

    def scan(self) -> List[Issue]:
        """Run all iOS diagnostic checks"""
        self.check_package_dependency()
        self.check_swift_files()
        return self.issues

    def check_package_dependency(self):
        """Check for SPM or CocoaPods dependency"""
        # Check Package.swift
        package_files = list(self.project_path.rglob("Package.swift"))
        podfile = list(self.project_path.rglob("Podfile"))

        found = False
        dependency_type = None

        # Check SPM
        for package_file in package_files:
            try:
                content = package_file.read_text()
                if 'TrustArcMobileConsent' in content or 'trustarc-mobile-consent' in content or 'trustarc_consent_sdk' in content:
                    found = True
                    dependency_type = "SPM"

                    # Try to extract version
                    version_match = re.search(r'from:\s*"(\d+\.\d+\.\d+)"', content) or \
                                   re.search(r'exact:\s*"(\d+\.\d+\.\d+)"', content)

                    if version_match:
                        version = version_match.group(1)
                        self.issues.append(Issue(
                            severity=Severity.SUCCESS,
                            category="Dependency",
                            message=f"TrustArc SDK found in Package.swift (version {version})",
                            file_path=str(package_file)
                        ))
                    else:
                        self.issues.append(Issue(
                            severity=Severity.SUCCESS,
                            category="Dependency",
                            message="TrustArc SDK found in Package.swift",
                            file_path=str(package_file)
                        ))
                    break
            except Exception:
                continue

        # Check CocoaPods
        if not found:
            for pod in podfile:
                try:
                    content = pod.read_text()
                    if 'TrustArcMobileConsent' in content or 'trustarc_consent_sdk' in content:
                        found = True
                        dependency_type = "CocoaPods"

                        # Try to extract version
                        version_match = re.search(r"pod\s+['\"].*?['\"],\s*['\"]~>\s*(\d+\.\d+\.\d+)['\"]", content)

                        if version_match:
                            version = version_match.group(1)
                            self.issues.append(Issue(
                                severity=Severity.SUCCESS,
                                category="Dependency",
                                message=f"TrustArc SDK found in Podfile (version ~> {version})",
                                file_path=str(pod)
                            ))
                        else:
                            self.issues.append(Issue(
                                severity=Severity.SUCCESS,
                                category="Dependency",
                                message="TrustArc SDK found in Podfile",
                                file_path=str(pod)
                            ))
                        break
                except Exception:
                    continue

        if not found:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Dependency",
                message="TrustArc SDK dependency not found",
                suggestion="Add TrustArc SDK via SPM (Package.swift) or CocoaPods (Podfile)"
            ))

    def check_swift_files(self):
        """Check Swift files for SDK usage"""
        swift_files = list(self.project_path.rglob("*.swift"))

        sdk_files = []
        for swift_file in swift_files:
            try:
                content = swift_file.read_text()
                # Look for the correct import statement (lowercase with underscores)
                if 'TrustArc' in content and 'import trustarc_consent_sdk' in content:
                    sdk_files.append((swift_file, content))
            except Exception:
                continue

        if not sdk_files:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Implementation",
                message="No TrustArc SDK usage found in Swift files",
                suggestion="Import SDK with: import trustarc_consent_sdk"
            ))
            return

        # Check for proper initialization
        self.check_initialization_patterns(sdk_files)

    def check_initialization_patterns(self, sdk_files):
        """Check iOS initialization patterns"""
        has_shared_instance = False
        has_set_domain = False
        has_start = False

        init_file = None

        for file_path, content in sdk_files:
            if re.search(self.REQUIRED_PATTERNS['shared_instance'], content):
                has_shared_instance = True
            if re.search(self.REQUIRED_PATTERNS['set_domain'], content):
                has_set_domain = True
                init_file = file_path
            if re.search(self.REQUIRED_PATTERNS['sdk_start'], content):
                has_start = True
                if init_file is None:
                    init_file = file_path

        # Report findings
        if has_shared_instance:
            self.issues.append(Issue(
                severity=Severity.SUCCESS,
                category="Architecture",
                message="Using TrustArc.sharedInstance singleton pattern",
                file_path=str(init_file) if init_file else None
            ))

        if has_set_domain and has_start:
            self.issues.append(Issue(
                severity=Severity.SUCCESS,
                category="Initialization",
                message="TrustArc SDK properly configured with setDomain() and start()",
                file_path=str(init_file)
            ))
        elif has_set_domain and not has_start:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Initialization",
                message="SDK domain configured but start() never called",
                file_path=str(init_file),
                suggestion="Call TrustArc.sharedInstance.start { } to initialize SDK"
            ))
        elif not has_set_domain:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Initialization",
                message="SDK not initialized - missing setDomain() call",
                suggestion="Configure SDK with: TrustArc.sharedInstance.setDomain(\"your.domain\").start { }"
            ))

        # Check for debug logging
        has_debug = any(re.search(r'\.enableDebugLogs?\s*\(', content) for _, content in sdk_files)
        if has_start and not has_debug:
            self.issues.append(Issue(
                severity=Severity.INFO,
                category="Configuration",
                message="Consider enabling debug logging for development",
                suggestion="Add: TrustArc.sharedInstance.enableDebugLogs(true)"
            ))


class ReactNativeDiagnostic:
    """React Native-specific diagnostic checks"""

    def __init__(self, project_path: str):
        self.project_path = Path(project_path)
        self.issues: List[Issue] = []

    def scan(self) -> List[Issue]:
        """Run all React Native diagnostic checks"""
        self.check_package_json()
        self.check_js_ts_files()
        return self.issues

    def check_package_json(self):
        """Check package.json for TrustArc dependency"""
        package_json = self.project_path / "package.json"

        if not package_json.exists():
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Configuration",
                message="package.json not found",
                suggestion="Ensure you're in a React Native project directory"
            ))
            return

        try:
            with open(package_json) as f:
                data = json.load(f)
                dependencies = {**data.get('dependencies', {}), **data.get('devDependencies', {})}

                trustarc_found = any('trustarc' in dep.lower() for dep in dependencies.keys())

                if trustarc_found:
                    self.issues.append(Issue(
                        severity=Severity.SUCCESS,
                        category="Dependency",
                        message="TrustArc package found in package.json",
                        file_path=str(package_json)
                    ))
                else:
                    self.issues.append(Issue(
                        severity=Severity.ERROR,
                        category="Dependency",
                        message="TrustArc package not found in dependencies",
                        suggestion="Add TrustArc React Native SDK to package.json"
                    ))
        except Exception as e:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Configuration",
                message=f"Error reading package.json: {str(e)}"
            ))

    def check_js_ts_files(self):
        """Check JS/TS files for SDK usage"""
        code_files = list(self.project_path.rglob("*.js")) + \
                     list(self.project_path.rglob("*.jsx")) + \
                     list(self.project_path.rglob("*.ts")) + \
                     list(self.project_path.rglob("*.tsx"))

        # Filter out node_modules
        code_files = [f for f in code_files if 'node_modules' not in str(f)]

        sdk_files = []
        for code_file in code_files:
            try:
                content = code_file.read_text()
                if 'trustarc' in content.lower() or 'TrustArc' in content:
                    sdk_files.append((code_file, content))
            except Exception:
                continue

        if not sdk_files:
            self.issues.append(Issue(
                severity=Severity.WARNING,
                category="Implementation",
                message="No TrustArc SDK usage found in code files",
                suggestion="Import and use TrustArc SDK in your code"
            ))


class FlutterDiagnostic:
    """Flutter-specific diagnostic checks"""

    def __init__(self, project_path: str):
        self.project_path = Path(project_path)
        self.issues: List[Issue] = []

    def scan(self) -> List[Issue]:
        """Run all Flutter diagnostic checks"""
        self.check_pubspec()
        self.check_dart_files()
        return self.issues

    def check_pubspec(self):
        """Check pubspec.yaml for TrustArc dependency"""
        pubspec = self.project_path / "pubspec.yaml"

        if not pubspec.exists():
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Configuration",
                message="pubspec.yaml not found",
                suggestion="Ensure you're in a Flutter project directory"
            ))
            return

        try:
            content = pubspec.read_text()
            if 'trustarc' in content.lower():
                self.issues.append(Issue(
                    severity=Severity.SUCCESS,
                    category="Dependency",
                    message="TrustArc package found in pubspec.yaml",
                    file_path=str(pubspec)
                ))
            else:
                self.issues.append(Issue(
                    severity=Severity.ERROR,
                    category="Dependency",
                    message="TrustArc package not found in pubspec.yaml",
                    suggestion="Add TrustArc Flutter SDK to dependencies"
                ))
        except Exception as e:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Configuration",
                message=f"Error reading pubspec.yaml: {str(e)}"
            ))

    def check_dart_files(self):
        """Check Dart files for SDK usage"""
        dart_files = list(self.project_path.rglob("*.dart"))

        sdk_files = []
        for dart_file in dart_files:
            try:
                content = dart_file.read_text()
                if 'trustarc' in content.lower() or 'TrustArc' in content:
                    sdk_files.append((dart_file, content))
            except Exception:
                continue

        if not sdk_files:
            self.issues.append(Issue(
                severity=Severity.WARNING,
                category="Implementation",
                message="No TrustArc SDK usage found in Dart files",
                suggestion="Import and use TrustArc SDK in your code"
            ))


class ProjectDiagnostic:
    """Main diagnostic orchestrator"""

    def __init__(self, project_path: str):
        self.project_path = Path(project_path).resolve()
        self.platform = self.detect_platform()

    def detect_platform(self) -> Platform:
        """Detect project platform"""
        path = self.project_path

        # Check for Flutter
        if (path / "pubspec.yaml").exists():
            try:
                content = (path / "pubspec.yaml").read_text()
                if 'flutter' in content.lower():
                    return Platform.FLUTTER
            except:
                pass

        # Check for React Native
        if (path / "package.json").exists():
            try:
                with open(path / "package.json") as f:
                    data = json.load(f)
                    deps = {**data.get('dependencies', {}), **data.get('devDependencies', {})}
                    if 'react-native' in deps:
                        return Platform.REACT_NATIVE
            except:
                pass

        # Check for iOS
        if list(path.rglob("*.xcodeproj")) or list(path.rglob("*.xcworkspace")) or (path / "Podfile").exists():
            return Platform.IOS

        # Check for Android
        if (path / "build.gradle").exists() or (path / "build.gradle.kts").exists() or \
           list(path.rglob("build.gradle")) or list(path.rglob("build.gradle.kts")):
            return Platform.ANDROID

        return Platform.UNKNOWN

    def run_diagnostic(self) -> DiagnosticReport:
        """Run platform-specific diagnostic"""
        issues = []
        sdk_found = False
        initialization_found = False

        if self.platform == Platform.ANDROID:
            diagnostic = AndroidDiagnostic(str(self.project_path))
            issues = diagnostic.scan()
        elif self.platform == Platform.IOS:
            diagnostic = iOSDiagnostic(str(self.project_path))
            issues = diagnostic.scan()
        elif self.platform == Platform.REACT_NATIVE:
            diagnostic = ReactNativeDiagnostic(str(self.project_path))
            issues = diagnostic.scan()
        elif self.platform == Platform.FLUTTER:
            diagnostic = FlutterDiagnostic(str(self.project_path))
            issues = diagnostic.scan()
        else:
            issues.append(Issue(
                severity=Severity.ERROR,
                category="Platform",
                message="Unknown platform - could not detect project type",
                suggestion="Ensure you're in a valid iOS, Android, React Native, or Flutter project"
            ))

        # Determine if SDK is found
        sdk_found = any(issue.category == "Dependency" and issue.severity == Severity.SUCCESS
                       for issue in issues)

        # Determine if initialization is found
        initialization_found = any(issue.category == "Initialization" and issue.severity == Severity.SUCCESS
                                  for issue in issues)

        # Calculate score
        score = self.calculate_score(issues, sdk_found, initialization_found)

        report = DiagnosticReport(
            platform=self.platform,
            project_path=str(self.project_path),
            issues=issues,
            sdk_found=sdk_found,
            initialization_found=initialization_found,
            score=score
        )

        guide_entries = GuideKnowledge.get_entries(self.platform)
        report.guide_insights = [
            {"title": title, "detail": detail}
            for title, detail in guide_entries
        ]

        reasoner = AIReasoner(report)
        report.ai_questions = reasoner.generate_context_questions()
        report.platform_neurolink = reasoner.generate_platform_neurolink()

        return report

    def calculate_score(self, issues: List[Issue], sdk_found: bool, initialization_found: bool) -> int:
        """Calculate diagnostic score (0-100)"""
        score = 100

        # Deduct points for issues
        for issue in issues:
            if issue.severity == Severity.ERROR:
                score -= 20
            elif issue.severity == Severity.WARNING:
                score -= 10

        # Bonus for SDK found
        if not sdk_found:
            score -= 30

        return max(0, min(100, score))


def format_report_text(report: DiagnosticReport) -> str:
    """Format diagnostic report as text"""
    lines = []

    lines.append("=" * 80)
    lines.append("TrustArc SDK Diagnostic Report")
    lines.append("=" * 80)
    lines.append("")
    lines.append(f"Platform: {report.platform.value}")
    lines.append(f"Project: {report.project_path}")
    lines.append(f"Score: {report.score}/100")
    lines.append("")

    # Group issues by severity
    errors = [i for i in report.issues if i.severity == Severity.ERROR]
    warnings = [i for i in report.issues if i.severity == Severity.WARNING]
    infos = [i for i in report.issues if i.severity == Severity.INFO]
    successes = [i for i in report.issues if i.severity == Severity.SUCCESS]

    if successes:
        lines.append("✓ SUCCESSES:")
        lines.append("-" * 80)
        for issue in successes:
            lines.append(f"  {issue.message}")
            if issue.file_path:
                lines.append(f"    File: {issue.file_path}")
        lines.append("")

    if errors:
        lines.append("✗ ERRORS:")
        lines.append("-" * 80)
        for issue in errors:
            lines.append(f"  [{issue.category}] {issue.message}")
            if issue.file_path:
                lines.append(f"    File: {issue.file_path}")
                if issue.line_number:
                    lines.append(f"    Line: {issue.line_number}")
            if issue.suggestion:
                lines.append(f"    → {issue.suggestion}")
            lines.append("")

    if warnings:
        lines.append("⚠ WARNINGS:")
        lines.append("-" * 80)
        for issue in warnings:
            lines.append(f"  [{issue.category}] {issue.message}")
            if issue.file_path:
                lines.append(f"    File: {issue.file_path}")
            if issue.suggestion:
                lines.append(f"    → {issue.suggestion}")
            lines.append("")

    if infos:
        lines.append("ℹ INFO:")
        lines.append("-" * 80)
        for issue in infos:
            lines.append(f"  [{issue.category}] {issue.message}")
            if issue.suggestion:
                lines.append(f"    → {issue.suggestion}")
            lines.append("")

    if report.guide_insights:
        lines.append("Guide Insights (Mobile App Consent Integration Guide v3.1)")
        lines.append("-" * 80)
        for entry in report.guide_insights:
            title = entry.get("title", "Insight")
            detail = entry.get("detail", "").strip()
            if detail:
                lines.append(f"- {title}: {detail}")
            else:
                lines.append(f"- {title}")
        lines.append("")

    if report.platform_neurolink:
        lines.append("AI Neurolink")
        lines.append("-" * 80)
        lines.append(report.platform_neurolink)
        lines.append("")

    if report.ai_questions:
        lines.append("Ask Questions (Q&A)")
        lines.append("-" * 80)
        for idx, qa in enumerate(report.ai_questions, start=1):
            question = qa.get("question", "").strip()
            answer = qa.get("answer", "").strip()
            if question:
                lines.append(f"Q{idx}: {question}")
            if answer:
                lines.append(f"A{idx}: {answer}")
            lines.append("")

    lines.append("=" * 80)

    return "\n".join(lines)


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: diagnose.py <project_path> [--json]")
        sys.exit(1)

    project_path = sys.argv[1]
    output_json = "--json" in sys.argv

    if not os.path.exists(project_path):
        print(f"Error: Project path does not exist: {project_path}")
        sys.exit(1)

    # Run diagnostic
    diagnostic = ProjectDiagnostic(project_path)
    report = diagnostic.run_diagnostic()

    # Output report
    if output_json:
        print(json.dumps(report.to_dict(), indent=2))
    else:
        print(format_report_text(report))

    # Exit with appropriate code
    sys.exit(0 if report.score >= 70 else 1)


if __name__ == "__main__":
    main()
