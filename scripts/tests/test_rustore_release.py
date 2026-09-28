import base64
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


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


class ReleaseArtifactVerificationTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.root = Path(self.temp_dir.name)
        self.run_id = "36399900001"
        self.release_tag = "android-v1.0.31+38"
        self.repository = "kamilgaraev/prohelper_mobile"
        self.commit_sha = "a" * 40
        self.run_metadata = {
            "id": int(self.run_id),
            "path": ".github/workflows/rustore-build.yml@refs/tags/android-v1.0.31+38",
            "event": "push",
            "status": "completed",
            "conclusion": "success",
            "head_branch": self.release_tag,
            "head_sha": self.commit_sha,
            "repository": {"full_name": self.repository},
            "head_repository": {"full_name": self.repository},
        }
        self.aab = self.root / "app-release.aab"
        self.aab.write_bytes(b"signed app bundle bytes")
        self.digest = hashlib.sha256(self.aab.read_bytes()).hexdigest()
        self.provenance = self.root / "provenance.json"
        self.provenance.write_text(
            json.dumps(
                {
                    "run_id": int(self.run_id),
                    "repository": self.repository,
                    "workflow_path": rustore_release.BUILD_WORKFLOW_PATH,
                    "event": "push",
                    "ref": f"refs/tags/{self.release_tag}",
                    "ref_name": self.release_tag,
                    "ref_type": "tag",
                    "commit_sha": self.commit_sha,
                    "aab_sha256": self.digest,
                }
            ),
            encoding="utf-8",
        )
        self.run_metadata_path = self.root / "run.json"
        self.run_metadata_path.write_text(json.dumps(self.run_metadata), encoding="utf-8")

    def test_accepts_signed_aab_only_from_successful_matching_build_run(self):
        actual = rustore_release.verify_release_artifact(
            aab_path=self.aab,
            provenance_path=self.provenance,
            run_metadata=self.run_metadata,
            run_id=self.run_id,
            expected_sha256=self.digest,
            release_tag=self.release_tag,
            repository=self.repository,
        )

        self.assertEqual(actual, self.digest)

    def test_rejects_hash_mismatch_before_ru_store_client_is_created(self):
        args = SimpleNamespace(
            tag=self.release_tag,
            aab=self.aab,
            expected_sha256="0" * 64,
            version_id=None,
            whats_new="Исправили ошибки",
            min_android_version=5,
            priority_update=0,
        )
        with patch("rustore_release.create_client") as create_client:
            with self.assertRaisesRegex(rustore_release.RuStoreError, "SHA-256"):
                rustore_release.submit_release(args)

        create_client.assert_not_called()

    def test_rejects_failed_or_unrelated_workflow_run(self):
        failed_run = dict(self.run_metadata, conclusion="failure")
        wrong_workflow = dict(
            self.run_metadata,
            path=".github/workflows/other.yml@refs/tags/android-v1.0.31+38",
        )

        for run in (failed_run, wrong_workflow):
            with self.subTest(run=run):
                with self.assertRaises(rustore_release.RuStoreError):
                    rustore_release.verify_build_run(
                        run,
                        run_id=self.run_id,
                        release_tag=self.release_tag,
                        repository=self.repository,
                    )


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

    @patch("rustore_release.create_client")
    def test_resumes_existing_draft_without_creating_another(self, create_client):
        client = MagicMock()
        create_client.return_value = client
        with tempfile.TemporaryDirectory() as temp_dir:
            artifact = Path(temp_dir) / "app-release.aab"
            artifact.write_bytes(b"test signed bundle")
            args = SimpleNamespace(
                tag="android-v1.0.1+5",
                aab=artifact,
                expected_sha256=hashlib.sha256(artifact.read_bytes()).hexdigest(),
                whats_new="Исправили ошибки",
                min_android_version=5,
                priority_update=0,
                version_id=2064757837,
            )

            rustore_release.submit_release(args)

        client.create_draft.assert_not_called()
        client.upload_aab.assert_called_once_with(2064757837, args.aab)
        client.commit_draft.assert_called_once_with(2064757837, 0)


class WorkflowContractTest(unittest.TestCase):
    def test_build_workflow_validates_and_uploads_aab_without_store_api(self):
        workflow = (
            REPOSITORY_ROOT / ".github" / "workflows" / "rustore-build.yml"
        ).read_text(encoding="utf-8")

        self.assertIn('tags:\n      - "android-v*"', workflow)
        self.assertIn("workflow_dispatch:", workflow)
        self.assertIn("flutter analyze --no-fatal-infos --no-fatal-warnings", workflow)
        self.assertIn("flutter test", workflow)
        self.assertIn("flutter build appbundle --release", workflow)
        self.assertIn("actions/upload-artifact@", workflow)
        self.assertIn("provenance.json", workflow)
        self.assertIn("tr -d '\\r\\n\\t '", workflow)
        self.assertIn("RUSTORE_PROJECT_ID: ${{ vars.RUSTORE_PROJECT_ID }}", workflow)
        signing_step = workflow.split("      - name: Подготовка подписи Android", 1)[1].split(
            "      - name: Сборка Android App Bundle", 1
        )[0]
        self.assertIn("ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}", signing_step)
        self.assertIn("ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}", signing_step)
        self.assertIn("ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}", signing_step)
        self.assertIn("ANDROID_STORE_PASSWORD: ${{ secrets.ANDROID_STORE_PASSWORD }}", signing_step)
        self.assertNotIn("ANDROID_KEYSTORE_BASE64:", workflow.split("      - name: Подготовка подписи Android", 1)[0])
        self.assertNotIn("RUSTORE_KEY_ID", workflow)
        self.assertNotIn("RUSTORE_PRIVATE_KEY", workflow)
        self.assertNotIn("rustore_release.py submit", workflow)
        self.assertNotIn("public-api.rustore.ru", workflow)
        self.assertRegex(workflow, r"actions/checkout@[0-9a-f]{40}")

    def test_submit_is_manual_and_guards_upload_with_successful_run_and_sha(self):
        workflow = (
            REPOSITORY_ROOT / ".github" / "workflows" / "rustore-submit.yml"
        ).read_text(encoding="utf-8")

        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotIn("\npush:", workflow)
        self.assertIn("build_run_id:", workflow)
        self.assertIn("expected_sha256:", workflow)
        self.assertIn("qa_attestation:", workflow)
        self.assertIn("I_VERIFIED_LOCAL_QA_AND_AAB_SHA256", workflow)
        self.assertIn("release_tag:", workflow)
        self.assertNotIn("inputs.version_id", workflow)
        self.assertIn("actions: read", workflow)
        self.assertIn("run-id: ${{ inputs.build_run_id }}", workflow)
        self.assertIn("name: rustore-aab-${{ inputs.build_run_id }}", workflow)
        self.assertIn("verify-run", workflow)
        self.assertIn("verify-artifact", workflow)
        self.assertNotIn("flutter build", workflow)
        self.assertNotIn("actions/upload-artifact@", workflow)

        verify_index = workflow.index("verify-artifact")
        run_verify_index = workflow.index("verify-run")
        download_index = workflow.index("Загрузка AAB из проверенного CI run")
        store_key_index = workflow.index("RUSTORE_KEY_ID")
        submit_index = workflow.index("Создание черновика и отправка")
        self.assertLess(run_verify_index, download_index)
        self.assertLess(download_index, verify_index)
        self.assertLess(verify_index, submit_index)
        self.assertLess(submit_index, store_key_index)
        self.assertRegex(workflow, r"actions/download-artifact@[0-9a-f]{40}")

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
