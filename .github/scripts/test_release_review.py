import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("review", Path(__file__).with_name("verify-release-review.py"))
review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(review)


class ReleaseReviewTest(unittest.TestCase):
    def setUp(self):
        self.sha = "a" * 40
        self.head = "b" * 40
        self.pr = {"number": 7, "head": {"sha": self.head}, "merged_at": "2026-01-01",
                   "base": {"ref": "main", "repo": {"full_name": "owner/project"}}, "merge_commit_sha": self.sha}
        self.report = {"commit_sha": self.head, "status": "completed", "has_unresolved_findings": False}

    def verify(self, *, bot_id=199175422, resolved=True, conclusion="success"):
        body = "<!-- codex-review-state:v1 " + review.json.dumps({"code_review": self.report}) + " -->"
        comment = {"body": body, "user": {"id": bot_id},
                   "performed_via_github_app": {"slug": "chatgpt-codex-connector"}}
        thread = {"data": {"repository": {"pullRequest": {"reviewThreads": {"nodes": [{"isResolved": resolved}]}}}}}
        run = {"id": 1, "head_sha": self.head, "path": ".github/workflows/pr-checks.yml",
               "pull_requests": [{"number": 7}], "status": "completed", "conclusion": conclusion}
        responses = [[[self.pr]], [[], [comment]], [thread], [{"workflow_runs": [run]}]]
        with patch.object(review, "pages", side_effect=responses):
            review.verify("owner/project", self.sha)

    def test_reviewed_squash(self):
        self.verify()

    def test_stale_review(self):
        self.report["commit_sha"] = "c" * 40
        with self.assertRaises(ValueError):
            self.verify()

    def test_open_thread(self):
        with self.assertRaises(ValueError):
            self.verify(resolved=False)

    def test_untrusted_author(self):
        with self.assertRaises(ValueError):
            self.verify(bot_id=123)

    def test_non_integrated_commit(self):
        self.pr["merge_commit_sha"] = self.head
        with self.assertRaises(ValueError):
            self.verify()

    def test_pending_review(self):
        self.report["status"] = "in_progress"
        with self.assertRaises(ValueError):
            self.verify()

    def test_malformed_report_is_rejected(self):
        self.report["commit_sha"] = self.head.upper()
        with self.assertRaises(ValueError):
            self.verify()

    def test_missing_pr_head_is_rejected(self):
        self.pr["head"]["sha"] = None
        self.report["commit_sha"] = None
        with self.assertRaises(ValueError):
            self.verify()

    def test_failed_ci(self):
        with self.assertRaises(ValueError):
            self.verify(conclusion="failure")


if __name__ == "__main__":
    unittest.main()
