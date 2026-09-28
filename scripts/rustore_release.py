#!/usr/bin/env python3

import argparse
import base64
import hashlib
import http.client
import json
import os
import re
import secrets
import subprocess
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable


API_ORIGIN = "https://public-api.rustore.ru"
TAG_PATTERN = re.compile(
    r"^android-v(?P<name>[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?)\+(?P<code>[0-9]+)$"
)


class RuStoreError(RuntimeError):
    pass


@dataclass(frozen=True)
class ReleaseVersion:
    name: str
    code: int


BUILD_WORKFLOW_PATH = ".github/workflows/rustore-build.yml"
SHA256_PATTERN = re.compile(r"^[0-9a-fA-F]{64}$")


def parse_release_tag(tag: str) -> ReleaseVersion:
    match = TAG_PATTERN.fullmatch(tag)
    if match is None:
        raise ValueError(
            "Тег должен иметь формат android-v<versionName>+<versionCode>"
        )
    code = int(match.group("code"))
    if code <= 0:
        raise ValueError("versionCode должен быть положительным целым числом")
    return ReleaseVersion(name=match.group("name"), code=code)


def load_json_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuStoreError(f"Не удалось прочитать {label}") from error
    if not isinstance(value, dict):
        raise RuStoreError(f"Некорректный формат {label}")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as artifact:
        for chunk in iter(lambda: artifact.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_build_run(
    run_metadata: dict[str, Any],
    *,
    run_id: str,
    release_tag: str,
    repository: str,
) -> str:
    if not run_id.isdecimal() or int(run_id) <= 0:
        raise RuStoreError("Идентификатор CI-сборки должен быть положительным числом")
    parse_release_tag(release_tag)
    try:
        run_repository = run_metadata["repository"]["full_name"]
        head_repository = run_metadata["head_repository"]["full_name"]
    except (KeyError, TypeError):
        raise RuStoreError("В данных CI-сборки отсутствует репозиторий") from None
    if str(run_metadata.get("id")) != run_id:
        raise RuStoreError("Идентификатор CI-сборки не совпадает")
    workflow_path = run_metadata.get("path")
    if not isinstance(workflow_path, str) or workflow_path.split("@", 1)[0] != BUILD_WORKFLOW_PATH:
        raise RuStoreError("Запуск создан не workflow сборки Android")
    if run_metadata.get("event") not in {"push", "workflow_dispatch"}:
        raise RuStoreError("Недопустимый источник CI-сборки")
    if run_metadata.get("status") != "completed" or run_metadata.get("conclusion") != "success":
        raise RuStoreError("CI-сборка Android не завершилась успешно")
    if run_metadata.get("head_branch") != release_tag:
        raise RuStoreError("Тег CI-сборки не совпадает с выбранным тегом")
    if run_repository != repository or head_repository != repository:
        raise RuStoreError("CI-сборка получена не из этого репозитория")
    head_sha = run_metadata.get("head_sha")
    if not isinstance(head_sha, str) or not re.fullmatch(r"[0-9a-fA-F]{40}", head_sha):
        raise RuStoreError("В данных CI-сборки отсутствует корректный commit SHA")
    return head_sha.lower()


def verify_run_metadata(args: argparse.Namespace) -> None:
    metadata = load_json_object(args.run_metadata, "данные CI-сборки")
    verify_build_run(
        metadata,
        run_id=args.run_id,
        release_tag=args.release_tag,
        repository=args.repository,
    )
    print(f"Проверена успешная Android-сборка {args.run_id} для {args.release_tag}")


def verify_release_artifact(
    *,
    aab_path: Path,
    provenance_path: Path,
    run_metadata: dict[str, Any],
    run_id: str,
    expected_sha256: str,
    release_tag: str,
    repository: str,
) -> str:
    if not SHA256_PATTERN.fullmatch(expected_sha256):
        raise RuStoreError("Ожидаемый SHA-256 должен содержать ровно 64 шестнадцатеричных символа")
    expected_sha256 = expected_sha256.lower()
    commit_sha = verify_build_run(
        run_metadata,
        run_id=run_id,
        release_tag=release_tag,
        repository=repository,
    )
    if not aab_path.is_file() or aab_path.suffix.lower() != ".aab":
        raise RuStoreError("Файл релиза AAB не найден")
    actual_sha256 = sha256_file(aab_path)
    if actual_sha256 != expected_sha256:
        raise RuStoreError("SHA-256 AAB не совпадает с утверждённым значением")

    provenance = load_json_object(provenance_path, "манифест AAB")
    expected_provenance = {
        "run_id": int(run_id),
        "repository": repository,
        "workflow_path": BUILD_WORKFLOW_PATH,
        "event": run_metadata.get("event"),
        "ref": f"refs/tags/{release_tag}",
        "ref_name": release_tag,
        "ref_type": "tag",
        "commit_sha": commit_sha,
        "aab_sha256": actual_sha256,
    }
    for key, expected in expected_provenance.items():
        if provenance.get(key) != expected:
            raise RuStoreError(f"Манифест AAB не совпадает с CI-сборкой: {key}")
    return actual_sha256


def verify_artifact(args: argparse.Namespace) -> None:
    metadata = load_json_object(args.run_metadata, "данные CI-сборки")
    digest = verify_release_artifact(
        aab_path=args.aab,
        provenance_path=args.provenance,
        run_metadata=metadata,
        run_id=args.run_id,
        expected_sha256=args.expected_sha256,
        release_tag=args.release_tag,
        repository=args.repository,
    )
    print(f"Подписанный AAB проверен: SHA-256 {digest}")


def sign_with_openssl(private_key: str, message: bytes) -> bytes:
    try:
        der_key = base64.b64decode("".join(private_key.split()), validate=True)
    except ValueError as error:
        raise RuStoreError("Приватный ключ RuStore имеет неверный формат") from error

    der_path: str | None = None
    pem_path: str | None = None
    try:
        with tempfile.NamedTemporaryFile(delete=False) as der_file:
            der_file.write(der_key)
            der_path = der_file.name
        with tempfile.NamedTemporaryFile(delete=False) as pem_file:
            pem_path = pem_file.name

        subprocess.run(
            ["openssl", "pkey", "-inform", "DER", "-in", der_path, "-out", pem_path],
            check=True,
            capture_output=True,
        )
        result = subprocess.run(
            ["openssl", "dgst", "-sha512", "-sign", pem_path],
            input=message,
            check=True,
            capture_output=True,
        )
        return result.stdout
    except (OSError, subprocess.CalledProcessError) as error:
        raise RuStoreError("Не удалось сформировать подпись запроса RuStore") from error
    finally:
        for path in (der_path, pem_path):
            if path is not None:
                Path(path).unlink(missing_ok=True)


def build_auth_payload(
    key_id: str,
    private_key: str,
    timestamp: str,
    signer: Callable[[str, bytes], bytes] = sign_with_openssl,
) -> dict[str, str]:
    message = f"{key_id}{timestamp}".encode()
    signature = base64.b64encode(signer(private_key, message)).decode()
    return {"keyId": key_id, "timestamp": timestamp, "signature": signature}


def require_ok(response: dict[str, Any]) -> Any:
    if response.get("code") != "OK":
        message = response.get("message") or "RuStore вернул ошибку без описания"
        raise RuStoreError(str(message))
    return response.get("body")


def build_draft_payload(whats_new: str, min_android_version: int) -> dict[str, Any]:
    text = whats_new.strip()
    if not text:
        raise ValueError("Описание изменений не может быть пустым")
    if not 1 <= min_android_version <= 16:
        raise ValueError("Минимальная версия Android должна быть от 1 до 16")
    return {
        "whatsNew": text,
        "publishType": "MANUAL",
        "partialValue": 100,
        "minAndroidVersion": min_android_version,
    }


def publication_action(status: str) -> str:
    if status == "READY_FOR_PUBLICATION":
        return "publish"
    if status in {"ACTIVE", "PARTIAL_ACTIVE"}:
        return "skip"
    raise RuStoreError(
        f"Версия имеет статус {status}, публикация пока недоступна"
    )


class RuStoreClient:
    def __init__(self, package_name: str, key_id: str, private_key: str):
        self.package_name = package_name
        self.key_id = key_id
        self.private_key = private_key
        self.token: str | None = None

    @property
    def application_path(self) -> str:
        package = urllib.parse.quote(self.package_name, safe="")
        return f"/public/v1/application/{package}"

    def authenticate(self) -> None:
        timestamp = datetime.now(timezone.utc).isoformat(timespec="milliseconds")
        payload = build_auth_payload(
            self.key_id,
            self.private_key,
            timestamp,
        )
        body = self._json_request("POST", "/public/auth/", payload, authenticated=False)
        token = body.get("jwe") if isinstance(body, dict) else None
        if not isinstance(token, str) or not token:
            raise RuStoreError("RuStore не вернул токен авторизации")
        self.token = token

    def create_draft(self, payload: dict[str, Any]) -> int:
        body = self._json_request("POST", f"{self.application_path}/version", payload)
        if not isinstance(body, int) or body <= 0:
            raise RuStoreError("RuStore не вернул корректный идентификатор версии")
        return body

    def upload_aab(self, version_id: int, file_path: Path) -> None:
        if not file_path.is_file() or file_path.suffix.lower() != ".aab":
            raise RuStoreError("Файл релиза AAB не найден")
        token = self._require_token()
        boundary = f"rustore-{secrets.token_hex(16)}"
        prefix = (
            f"--{boundary}\r\n"
            'Content-Disposition: form-data; name="file"; filename="app-release.aab"\r\n'
            "Content-Type: application/octet-stream\r\n\r\n"
        ).encode()
        suffix = f"\r\n--{boundary}--\r\n".encode()
        content_length = len(prefix) + file_path.stat().st_size + len(suffix)
        connection = http.client.HTTPSConnection("public-api.rustore.ru", timeout=600)
        try:
            path = f"{self.application_path}/version/{version_id}/aab"
            connection.putrequest("POST", path)
            connection.putheader("Accept", "application/json")
            connection.putheader("Public-Token", token)
            connection.putheader("Content-Type", f"multipart/form-data; boundary={boundary}")
            connection.putheader("Content-Length", str(content_length))
            connection.endheaders()
            connection.send(prefix)
            with file_path.open("rb") as bundle:
                while chunk := bundle.read(1024 * 1024):
                    connection.send(chunk)
            connection.send(suffix)
            response = connection.getresponse()
            response_body = response.read()
            require_ok(self._decode_response(response.status, response_body))
        finally:
            connection.close()

    def commit_draft(self, version_id: int, priority_update: int) -> None:
        path = (
            f"{self.application_path}/version/{version_id}/commit"
            f"?priorityUpdate={priority_update}"
        )
        self._json_request("POST", path)

    def version_status(self, version_id: int) -> str:
        body = self._json_request(
            "GET", f"{self.application_path}/version?ids={version_id}"
        )
        content = body.get("content") if isinstance(body, dict) else None
        if not isinstance(content, list) or len(content) != 1:
            raise RuStoreError("Версия с указанным идентификатором не найдена")
        status = content[0].get("versionStatus")
        if not isinstance(status, str) or not status:
            raise RuStoreError("RuStore не вернул статус версии")
        return status

    def publish(self, version_id: int) -> None:
        self._json_request(
            "POST", f"{self.application_path}/version/{version_id}/publish"
        )

    def _require_token(self) -> str:
        if self.token is None:
            raise RuStoreError("Клиент RuStore не авторизован")
        return self.token

    def _json_request(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
        authenticated: bool = True,
    ) -> Any:
        headers = {"Accept": "application/json"}
        data = None
        if payload is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(payload, ensure_ascii=False).encode()
        if authenticated:
            headers["Public-Token"] = self._require_token()
        request = urllib.request.Request(
            f"{API_ORIGIN}{path}",
            data=data,
            headers=headers,
            method=method,
        )
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                response_body = response.read()
                status = response.status
        except urllib.error.HTTPError as error:
            response_body = error.read()
            status = error.code
        except urllib.error.URLError as error:
            raise RuStoreError("Не удалось подключиться к RuStore") from error
        return require_ok(self._decode_response(status, response_body))

    @staticmethod
    def _decode_response(status: int, response_body: bytes) -> dict[str, Any]:
        try:
            decoded = json.loads(response_body.decode())
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise RuStoreError(f"RuStore вернул некорректный ответ HTTP {status}") from error
        if not isinstance(decoded, dict):
            raise RuStoreError(f"RuStore вернул некорректный ответ HTTP {status}")
        return decoded


def required_environment(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuStoreError(f"Не задана обязательная переменная {name}")
    return value


def create_client() -> RuStoreClient:
    return RuStoreClient(
        package_name=required_environment("RUSTORE_PACKAGE_NAME"),
        key_id=required_environment("RUSTORE_KEY_ID"),
        private_key=required_environment("RUSTORE_PRIVATE_KEY"),
    )


def write_github_output(name: str, value: str) -> None:
    output_file = os.environ.get("GITHUB_OUTPUT")
    if output_file:
        with Path(output_file).open("a", encoding="utf-8") as output:
            output.write(f"{name}={value}\n")


def submit_release(args: argparse.Namespace) -> None:
    version = parse_release_tag(args.tag)
    if not SHA256_PATTERN.fullmatch(args.expected_sha256):
        raise RuStoreError("Ожидаемый SHA-256 должен содержать ровно 64 шестнадцатеричных символа")
    if not args.aab.is_file() or args.aab.suffix.lower() != ".aab":
        raise RuStoreError("Файл релиза AAB не найден")
    actual_sha256 = sha256_file(args.aab)
    if actual_sha256 != args.expected_sha256.lower():
        raise RuStoreError("SHA-256 AAB не совпадает с утверждённым значением")
    client = create_client()
    client.authenticate()
    version_id = args.version_id
    if version_id is None:
        version_id = client.create_draft(
            build_draft_payload(args.whats_new, args.min_android_version)
        )
        print(f"Создана версия RuStore: {version_id}")
    else:
        print(f"Продолжается существующая версия RuStore: {version_id}")
    write_github_output("version_id", str(version_id))
    client.upload_aab(version_id, args.aab)
    client.commit_draft(version_id, args.priority_update)
    print(
        f"Версия {version.name} ({version.code}) отправлена на модерацию, "
        f"versionId: {version_id}"
    )


def publish_release(args: argparse.Namespace) -> None:
    client = create_client()
    client.authenticate()
    status = client.version_status(args.version_id)
    action = publication_action(status)
    if action == "skip":
        print(f"Версия {args.version_id} уже опубликована")
        return
    client.publish(args.version_id)
    print(f"Версия {args.version_id} опубликована")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)

    submit = commands.add_parser("submit")
    submit.add_argument("--tag", required=True)
    submit.add_argument("--aab", required=True, type=Path)
    submit.add_argument("--whats-new", required=True)
    submit.add_argument("--min-android-version", type=int, default=5)
    submit.add_argument("--priority-update", type=int, choices=range(0, 6), default=0)
    submit.add_argument("--version-id", type=int)
    submit.add_argument("--expected-sha256", required=True)
    submit.set_defaults(handler=submit_release)

    verify_run = commands.add_parser("verify-run")
    verify_run.add_argument("--run-metadata", required=True, type=Path)
    verify_run.add_argument("--run-id", required=True)
    verify_run.add_argument("--release-tag", required=True)
    verify_run.add_argument("--repository", required=True)
    verify_run.set_defaults(handler=verify_run_metadata)

    verify = commands.add_parser("verify-artifact")
    verify.add_argument("--aab", required=True, type=Path)
    verify.add_argument("--provenance", required=True, type=Path)
    verify.add_argument("--run-metadata", required=True, type=Path)
    verify.add_argument("--run-id", required=True)
    verify.add_argument("--expected-sha256", required=True)
    verify.add_argument("--release-tag", required=True)
    verify.add_argument("--repository", required=True)
    verify.set_defaults(handler=verify_artifact)

    publish = commands.add_parser("publish")
    publish.add_argument("--version-id", required=True, type=int)
    publish.set_defaults(handler=publish_release)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        args.handler(args)
        return 0
    except (RuStoreError, ValueError) as error:
        parser.error(str(error))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
