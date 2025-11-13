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
from dataclasses import dataclass, asdict
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

    def to_dict(self):
        return {
            'platform': self.platform.value,
            'project_path': self.project_path,
            'sdk_found': self.sdk_found,
            'initialization_found': self.initialization_found,
            'score': self.score,
            'issues': [issue.to_dict() for issue in self.issues]
        }


class AndroidDiagnostic:
    """Android-specific diagnostic checks"""

    REQUIRED_PATTERNS = {
        'sdk_import': r'import\s+com\.truste\.androidmobileconsentsdk\.TrustArc',
        'sdk_constructor': r'TrustArc\s*\(\s*\w+\s*,\s*SdkMode\.',
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

        found = False
        for gradle_file in gradle_files:
            try:
                content = gradle_file.read_text()
                if 'com.trustarc:trustarc-consent-sdk' in content:
                    found = True

                    # Check version
                    version_match = re.search(r'trustarc-consent-sdk["\']?\s*:\s*["\']?(\d+\.\d+\.\d+)', content)
                    if version_match:
                        version = version_match.group(1)
                        self.issues.append(Issue(
                            severity=Severity.SUCCESS,
                            category="Dependency",
                            message=f"TrustArc SDK found (version {version})",
                            file_path=str(gradle_file)
                        ))
                    break
            except Exception as e:
                continue

        if not found:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Dependency",
                message="TrustArc SDK dependency not found in gradle files",
                suggestion="Add: implementation(\"com.trustarc:trustarc-consent-sdk:VERSION\")"
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

        sdk_files = []
        for code_file in code_files:
            try:
                content = code_file.read_text()
                if 'TrustArc' in content and 'com.truste.androidmobileconsentsdk' in content:
                    sdk_files.append((code_file, content))
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

        for file_path, content in sdk_files:
            self.check_file_patterns(file_path, content)

    def check_file_patterns(self, file_path: Path, content: str):
        """Check individual file for patterns"""
        lines = content.split('\n')

        # Check for SDK constructor
        has_constructor = bool(re.search(self.REQUIRED_PATTERNS['sdk_constructor'], content))
        has_start = bool(re.search(self.REQUIRED_PATTERNS['sdk_start'], content))

        if has_constructor and not has_start:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Initialization",
                message="TrustArc instance created but start() never called",
                file_path=str(file_path),
                suggestion="Call trustArc.start(domainName = \"your.domain\")"
            ))

        # Check for recommended patterns
        if has_start and not re.search(self.RECOMMENDED_PATTERNS['enable_debug'], content):
            self.issues.append(Issue(
                severity=Severity.INFO,
                category="Configuration",
                message="Consider enabling debug logging for development",
                file_path=str(file_path),
                suggestion="Add: trustArc.enableDebugLog(true)"
            ))

        # Check initialization order
        constructor_line = -1
        start_line = -1

        for i, line in enumerate(lines):
            if re.search(r'TrustArc\s*\(', line):
                constructor_line = i
            if re.search(r'\.start\s*\(', line):
                start_line = i

        if constructor_line > 0 and start_line > 0 and start_line < constructor_line:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Initialization",
                message="start() called before TrustArc constructor",
                file_path=str(file_path),
                line_number=start_line + 1,
                suggestion="Ensure TrustArc instance is created before calling start()"
            ))

    def check_initialization_flow(self):
        """Check for proper initialization flow"""
        # This is a placeholder for more complex flow analysis
        pass


class iOSDiagnostic:
    """iOS-specific diagnostic checks"""

    REQUIRED_PATTERNS = {
        'sdk_import': r'import\s+TrustArcMobileConsent',
        'sdk_constructor': r'TrustArc\s*\(\s*context:',
        'sdk_start': r'\.start\s*\(',
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

        # Check SPM
        for package_file in package_files:
            try:
                content = package_file.read_text()
                if 'TrustArcMobileConsent' in content or 'trustarc-mobile-consent' in content:
                    found = True
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
                    if 'TrustArcMobileConsent' in content:
                        found = True
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
                suggestion="Add TrustArc SDK via SPM or CocoaPods"
            ))

    def check_swift_files(self):
        """Check Swift files for SDK usage"""
        swift_files = list(self.project_path.rglob("*.swift"))

        sdk_files = []
        for swift_file in swift_files:
            try:
                content = swift_file.read_text()
                if 'TrustArc' in content and 'import TrustArcMobileConsent' in content:
                    sdk_files.append((swift_file, content))
            except Exception:
                continue

        if not sdk_files:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Implementation",
                message="No TrustArc SDK usage found in Swift files",
                suggestion="Import and initialize TrustArc SDK"
            ))
            return

        for file_path, content in sdk_files:
            self.check_swift_patterns(file_path, content)

    def check_swift_patterns(self, file_path: Path, content: str):
        """Check Swift file for patterns"""
        has_constructor = bool(re.search(self.REQUIRED_PATTERNS['sdk_constructor'], content))
        has_start = bool(re.search(self.REQUIRED_PATTERNS['sdk_start'], content))

        if has_constructor and not has_start:
            self.issues.append(Issue(
                severity=Severity.ERROR,
                category="Initialization",
                message="TrustArc instance created but start() never called",
                file_path=str(file_path),
                suggestion="Call trustArc.start(domainName: \"your.domain\")"
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

        return DiagnosticReport(
            platform=self.platform,
            project_path=str(self.project_path),
            issues=issues,
            sdk_found=sdk_found,
            initialization_found=initialization_found,
            score=score
        )

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
