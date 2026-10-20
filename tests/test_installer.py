"""Exercise module downloads without network access or installer side effects.

Run with: python3 -m unittest discover -s tests
"""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


INSTALLER = Path(__file__).resolve().parents[1] / "install.sh"
SOURCE = INSTALLER.read_text()
LOADER = SOURCE.split("load_module() {", 1)[1].split("# Cleanup function", 1)[0]
LOADER = "load_module() {" + LOADER

MOCKS = r"""
mock_download() {
    local output=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -o|-O) output="$2"; shift ;;
        esac
        shift
    done
    local count=0
    [ ! -f "$TEST_DIR/attempts" ] || count=$(cat "$TEST_DIR/attempts")
    count=$((count + 1))
    echo "$count" > "$TEST_DIR/attempts"
    local outcome="$OUTCOME"
    if [ "$RECOVER" = "1" ] && [ "$count" -gt 1 ]; then
        outcome=success
    fi
    case "$outcome" in
        success)
            echo 'echo MODULE_SOURCED' > "$output"
            [ "$CLIENT" != curl ] || printf 200
            return 0 ;;
        empty)
            : > "$output"
            [ "$CLIENT" != curl ] || printf 200
            return 0 ;;
        rate_limit)
            [ "$CLIENT" != curl ] || printf 429
            echo "mock: rate limited" >&2
            return 22 ;;
        not_found)
            echo 'echo INVALID_MODULE_SOURCED' > "$output"
            printf 404
            return 22 ;;
        partial)
            echo 'echo INVALID_MODULE_SOURCED' > "$output"
            [ "$CLIENT" != curl ] || printf 200
            echo "mock: incomplete transfer" >&2
            return 18 ;;
        network)
            [ "$CLIENT" != curl ] || printf 000
            echo "mock: connection failed" >&2
            return 7 ;;
    esac
}
curl() { mock_download "$@"; }
wget() { mock_download "$@"; }
command() {
    if [ "$1" = "-v" ] && [ "$2" = curl ] && [ "$CLIENT" = wget ]; then
        return 1
    fi
    builtin command "$@"
}
sleep() { echo "$1" >> "$TEST_DIR/delays"; }
"""


class InstallerDownloadsTest(unittest.TestCase):
    def run_download(self, client, outcome, recover=False):
        with tempfile.TemporaryDirectory(prefix="trustarc-test-") as directory:
            env = {
                "PATH": os.environ["PATH"],
                "TEST_DIR": directory,
                "CLIENT": client,
                "OUTCOME": outcome,
                "RECOVER": "1" if recover else "0",
            }
            script = (
                "set -e\n"
                'USE_LOCAL_MODULES=0\n_RAW_AUTH_TOKEN=""\n'
                'REPO_REF=main\n'
                'REPO_BASE_URL=https://example.invalid\n'
                'TMP_LIB_DIR="$TEST_DIR/modules"\n'
                + MOCKS
                + LOADER
                + '\nload_module "utils"\necho LOADER_FINISHED\n'
            )
            result = subprocess.run(
                ["/bin/bash", "-c", script],
                env=env,
                capture_output=True,
                text=True,
                timeout=10,
            )
            attempts = int((Path(directory) / "attempts").read_text())
            delays_file = Path(directory) / "delays"
            delays = delays_file.read_text().splitlines() if delays_file.exists() else []
            module_exists = (Path(directory) / "modules/utils.sh").exists()
        return result, attempts, delays, module_exists

    def test_missing_module_fails_immediately_with_url(self):
        result, attempts, delays, exists = self.run_download("curl", "not_found")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(attempts, 1)
        self.assertEqual(delays, [])
        self.assertFalse(exists)
        self.assertIn("https://example.invalid/lib/utils.sh", result.stderr)
        self.assertIn("REPO_REF=main", result.stderr)
        self.assertNotIn("MODULE_SOURCED", result.stdout)

    def test_success(self):
        for client in ("curl", "wget"):
            with self.subTest(client=client):
                result, attempts, delays, _ = self.run_download(client, "success")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("MODULE_SOURCED\nLOADER_FINISHED", result.stdout)
                self.assertEqual(attempts, 1)
                self.assertEqual(delays, [])

    def test_failure_retries_and_reports_error(self):
        for client in ("curl", "wget"):
            for outcome in ("rate_limit", "network", "partial", "empty"):
                with self.subTest(client=client, outcome=outcome):
                    result, attempts, delays, exists = self.run_download(client, outcome)
                    self.assertEqual(result.returncode, 1)
                    self.assertEqual(attempts, 5)
                    self.assertEqual(delays, ["2", "4", "8", "16"])
                    self.assertIn("Failed to download module after 5 attempts", result.stdout)
                    self.assertIn("attempt 5/5", result.stderr)
                    self.assertNotIn("MODULE_SOURCED", result.stdout)
                    self.assertNotIn("LOADER_FINISHED", result.stdout)
                    self.assertFalse(exists)
                    if outcome != "empty":
                        self.assertIn("mock:", result.stderr)
                    if client == "curl" and outcome == "rate_limit":
                        self.assertIn("GitHub rate limit hit", result.stderr)

    def test_recovers_after_failure(self):
        for client in ("curl", "wget"):
            for outcome in ("rate_limit", "network", "partial", "empty"):
                with self.subTest(client=client, outcome=outcome):
                    result, attempts, delays, _ = self.run_download(client, outcome, True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(attempts, 2)
                    self.assertEqual(delays, ["2"])
                    self.assertIn("MODULE_SOURCED\nLOADER_FINISHED", result.stdout)
                    self.assertNotIn("INVALID_MODULE_SOURCED", result.stdout)


class InstallerRefTest(unittest.TestCase):
    def test_cli_and_sample_refs(self):
        selection = SOURCE.split("# GitHub repository base URL", 1)[1].split(
            "# By default, always fetch", 1
        )[0]
        selection = "# GitHub repository base URL" + selection
        samples = (INSTALLER.parent / "lib/download.sh").read_text().split(
            "sample_repo_archive_url()", 1
        )[0]
        cases = [
            ({}, "main", "release"),
            ({"TRUSTARC_REF": "release"}, "main", "release"),
            ({"TRUSTARC_REF": "v2.0.0"}, "main", "v2.0.0"),
            ({"TRUSTARC_REF": "testing"}, "testing", "testing"),
            ({"TRUSTARC_REF": "main"}, "main", "main"),
            ({"TRUSTARC_REF": "release", "TRUSTARC_CLI_REF": "testing"}, "testing", "release"),
            ({"CLI_VERSION": "testing"}, "testing", "testing"),
            ({"REPO_REF": "custom", "TRUSTARC_CLI_REF": "testing"}, "custom", "custom"),
        ]
        for variables, cli_ref, sample_ref in cases:
            with self.subTest(variables=variables):
                result = subprocess.run(
                    ["/bin/bash", "-c", "set -e\n" + selection + samples
                     + '\nprintf "%s\\n%s\\n" "$REPO_REF" "$SAMPLE_REPO_BRANCH"'],
                    env={"PATH": os.environ["PATH"], **variables},
                    capture_output=True, text=True, timeout=10,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(), [cli_ref, sample_ref])


if __name__ == "__main__":
    unittest.main()
