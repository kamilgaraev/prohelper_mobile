import base64
import sys
import unittest
from pathlib import Path


SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

import rustore_release


REPOSITORY_ROOT = SCRIPTS_DIR.parent


class ReleaseTagTest(unittest.TestCase):
    def test_parses_android_release_tag(self):
        version = rustore_release.parse_release_tag("android-v1.2.0+42")

        self.assertEqual(version.name, "1.2.0")
        self.assertEqual(version.code, 42)

    def test_rejects_non_positive_version_code(self):
        with self.assertRaisesRegex(ValueError, "versionCode"):
            rustore_release.parse_release_tag("android-v1.2.0+0")

    def test_rejects_unexpected_tag(self):
        with self.assertRaisesRegex(ValueError, "android-v"):
            rustore_release.parse_release_tag("v1.2.0")


class AuthenticationTest(unittest.TestCase):
    def test_builds_signature_message_from_key_and_timestamp(self):
        captured = {}

        def signer(private_key, message):
            captured["private_key"] = private_key
            captured["message"] = message
            return b"signature"

        payload = rustore_release.build_auth_payload(
            key_id="123",
            private_key="private-key",
            timestamp="2026-08-11T10:00:00.000+00:00",
            signer=signer,
        )

        self.assertEqual(captured["private_key"], "private-key")
        self.assertEqual(
            captured["message"], b"1232026-08-11T10:00:00.000+00:00"
        )
        self.assertEqual(payload["keyId"], "123")
        self.assertEqual(payload["signature"], base64.b64encode(b"signature").decode())


class ApiContractTest(unittest.TestCase):
    def test_extracts_successful_body(self):
        self.assertEqual(
            rustore_release.require_ok({"code": "OK", "body": 734}),
            734,
        )

    def test_rejects_error_response_without_exposing_payload(self):
        with self.assertRaisesRegex(rustore_release.RuStoreError, "Доступ запрещён"):
            rustore_release.require_ok(
                {"code": "ERROR", "message": "Доступ запрещён", "body": "secret"}
            )

    def test_builds_manual_release_draft(self):
        self.assertEqual(
            rustore_release.build_draft_payload(
                whats_new="Исправили ошибки",
                min_android_version=5,
            ),
            {
                "whatsNew": "Исправили ошибки",
                "publishType": "MANUAL",
                "partialValue": 100,
                "minAndroidVersion": 5,
            },
        )

    def test_allows_publication_only_for_approved_version(self):
        self.assertEqual(
            rustore_release.publication_action("READY_FOR_PUBLICATION"),
            "publish",
        )
        self.assertEqual(rustore_release.publication_action("ACTIVE"), "skip")
        with self.assertRaisesRegex(rustore_release.RuStoreError, "MODERATION"):
            rustore_release.publication_action("MODERATION")


class WorkflowContractTest(unittest.TestCase):
    def test_submit_workflow_runs_only_for_android_tags_with_production_secrets(self):
        workflow = (
            REPOSITORY_ROOT / ".github" / "workflows" / "rustore-submit.yml"
        ).read_text(encoding="utf-8")

        self.assertIn("android-v*", workflow)
        self.assertIn("environment: rustore-production", workflow)
        self.assertIn("contents: read", workflow)
        self.assertIn("flutter analyze --no-fatal-infos --no-fatal-warnings", workflow)
        self.assertIn("tr -d '\\r\\n\\t '", workflow)
        self.assertNotIn("pull_request:", workflow)
        self.assertRegex(workflow, r"actions/checkout@[0-9a-f]{40}")

    def test_publish_workflow_requires_manual_dispatch_and_production_environment(self):
        workflow = (
            REPOSITORY_ROOT / ".github" / "workflows" / "rustore-publish.yml"
        ).read_text(encoding="utf-8")

        self.assertIn("workflow_dispatch:", workflow)
        self.assertIn("version_id:", workflow)
        self.assertIn("environment: rustore-production", workflow)
        self.assertNotIn("push:", workflow)


if __name__ == "__main__":
    unittest.main()
