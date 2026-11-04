import json
import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/generate-release-notes.sh"
WORKFLOW = SCRIPT.parents[1] / ".github/workflows/release.yml"


class ReleaseNotesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        self.source.mkdir()
        self.git("init", "--initial-branch=main")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        self.commit("Initial source")
        self.initial_sha = self.git("rev-parse", "HEAD")
        self.git("tag", "v1.0.0")
        self.commit("Add upstream feature")
        self.sha = self.git("rev-parse", "HEAD")
        self.git("tag", "v1.1.0")
        self.releases = self.root / "releases.json"
        self.releases.write_text("[[]]")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        gh = self.bin / "gh"
        gh.write_text(
            "#!/bin/bash\n"
            "set -eu\n"
            'printf "%s\\n" "$@" > "$GH_CALL"\n'
            'if [ "${GH_FAIL:-false}" = true ]; then\n'
            '  echo "API unavailable" >&2\n'
            "  exit 1\n"
            "fi\n"
            'cat "$RELEASE_FIXTURE"\n'
        )
        gh.chmod(0o755)
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "RELEASE_FIXTURE": str(self.releases),
            "GH_CALL": str(self.root / "gh-call"),
        }

    def git(self, *args):
        return subprocess.check_output(
            ["git", "-C", str(self.source), *args], text=True, stderr=subprocess.PIPE
        ).strip()

    def commit(self, message):
        self.git("commit", "--allow-empty", "-m", message)

    def generate(self, ref="v1.1.0", repo="AmadeusITGroup/ai-primitives-hub"):
        return subprocess.run(
            ["bash", str(SCRIPT), str(self.source), repo, ref],
            env=self.env,
            text=True,
            capture_output=True,
        )

    def resolve_source(self, ref):
        step = WORKFLOW.read_text().split("      - name: Resolve upstream source\n", 1)[1]
        script = textwrap.dedent(
            step.split("        run: |\n", 1)[1].split("\n  build-binaries:", 1)[0]
        )
        output = self.root / "source-output"
        result = subprocess.run(
            ["bash", "-euo", "pipefail", "-c", script],
            cwd=self.source,
            env={
                **self.env,
                "SOURCE_REPO": "example/fork",
                "SOURCE_REF": ref,
                "GITHUB_OUTPUT": str(output),
            },
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return dict(line.split("=", 1) for line in output.read_text().splitlines())

    def test_workflow_pins_checked_out_branch_when_tag_has_same_name(self):
        self.git("branch", "v1.0.0", self.sha)
        self.git("checkout", "refs/heads/v1.0.0")
        self.assertEqual(self.git("rev-parse", "HEAD"), self.sha)
        self.assertEqual(self.git("rev-parse", "v1.0.0^{commit}"), self.initial_sha)
        source = self.resolve_source("v1.0.0")
        self.assertEqual(source["sha"], self.sha)
        self.assertEqual(source["ref"], "v1.0.0")
        self.assertEqual(source["repo"], "example/fork")

    def test_workflow_default_still_resolves_latest_reachable_tag(self):
        self.commit("Unreleased change")
        source = self.resolve_source("")
        self.assertEqual(source["sha"], self.sha)
        self.assertEqual(source["ref"], "v1.1.0")

    def test_workflow_pins_annotated_tag_commit(self):
        self.git("tag", "-a", "v2.0.0", "-m", "Annotated release")
        self.git("checkout", "--detach", "v2.0.0")
        source = self.resolve_source("v2.0.0")
        self.assertEqual(source["sha"], self.sha)
        self.assertEqual(source["ref"], "v2.0.0")

    def test_reuses_matching_upstream_release(self):
        self.releases.write_text(json.dumps([
            [{"tag_name": "v9.0.0", "body": "Wrong release"}],
            [{"tag_name": "v1.1.0", "body": "## Upstream notes\nA feature"}],
        ]))
        result = self.generate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("## Upstream notes\nA feature", result.stdout)
        self.assertNotIn("Wrong release", result.stdout)
        self.assertNotIn("What's Changed", result.stdout)
        self.assertIn(f"/commit/{self.sha}", result.stdout)
        self.assertIn(
            "repos/AmadeusITGroup/ai-primitives-hub/releases",
            (self.root / "gh-call").read_text(),
        )

    def test_missing_release_uses_upstream_commit_range(self):
        result = self.generate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Add upstream feature", result.stdout)
        self.assertNotIn("Initial source", result.stdout)
        self.assertIn(f"/compare/v1.0.0...{self.sha}", result.stdout)
        self.assertNotIn("gh-ai-primitives-hub/compare", result.stdout)

    def test_empty_release_body_uses_commit_range(self):
        for body in (None, "", " \n "):
            with self.subTest(body=body):
                self.releases.write_text(json.dumps([
                    [{"tag_name": "v1.1.0", "body": body}]
                ]))
                result = self.generate()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("Add upstream feature", result.stdout)

    def test_branch_without_tag_uses_pinned_commit_and_custom_repo(self):
        self.commit("Unreleased branch work")
        sha = self.git("rev-parse", "HEAD")
        result = self.generate(ref="main", repo="example/fork")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Unreleased branch work", result.stdout)
        self.assertNotIn("Add upstream feature", result.stdout)
        self.assertIn(f"https://github.com/example/fork/compare/v1.1.0...{sha}", result.stdout)
        self.assertIn("(ref: `main`)", result.stdout)
        self.assertFalse((self.root / "gh-call").exists())

    def test_first_release_uses_full_history(self):
        self.git("checkout", "--detach", self.initial_sha)
        result = self.generate(ref="v1.0.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Initial source", result.stdout)
        self.assertNotIn("Add upstream feature", result.stdout)
        self.assertIn(f"/commits/{self.initial_sha}", result.stdout)

    def test_requested_tag_wins_when_commit_has_multiple_tags(self):
        self.git("tag", "-a", "v2.0.0", "-m", "Annotated alias")
        self.releases.write_text(json.dumps([
            [
                {"tag_name": "v1.1.0", "body": "Requested release"},
                {"tag_name": "v2.0.0", "body": "Other release"},
            ]
        ]))
        result = self.generate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Requested release", result.stdout)
        self.assertNotIn("Other release", result.stdout)

    def test_untagged_history_uses_full_history_without_api(self):
        self.git("tag", "-d", "v1.0.0", "v1.1.0")
        result = self.generate(ref=self.sha)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Initial source", result.stdout)
        self.assertIn("Add upstream feature", result.stdout)
        self.assertIn(f"/commits/{self.sha}", result.stdout)
        self.assertFalse((self.root / "gh-call").exists())

    def test_unrelated_tag_is_not_used_as_previous_release(self):
        self.git("checkout", "-b", "unrelated", self.initial_sha)
        self.commit("Other branch")
        self.git("tag", "v9.0.0")
        self.git("checkout", "main")
        result = self.generate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"/compare/v1.0.0...{self.sha}", result.stdout)
        self.assertNotIn("Other branch", result.stdout)

    def test_api_errors_fail_instead_of_silently_falling_back(self):
        self.env["GH_FAIL"] = "true"
        result = self.generate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("API unavailable", result.stderr)
        self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
