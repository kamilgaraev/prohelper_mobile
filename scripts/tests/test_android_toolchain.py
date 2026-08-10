import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class AndroidReleaseToolchainTest(unittest.TestCase):
    def test_toolchain_supports_compile_sdk_36(self):
        settings = (ROOT / "android" / "settings.gradle.kts").read_text(
            encoding="utf-8"
        )
        wrapper = (
            ROOT / "android" / "gradle" / "wrapper" / "gradle-wrapper.properties"
        ).read_text(encoding="utf-8")
        app = (ROOT / "android" / "app" / "build.gradle.kts").read_text(
            encoding="utf-8"
        )

        self.assertIn('com.android.application") version "8.11.1"', settings)
        self.assertIn('org.jetbrains.kotlin.android") version "2.2.20"', settings)
        self.assertIn("gradle-8.13-all.zip", wrapper)
        self.assertIn("compileSdk = 36", app)


if __name__ == "__main__":
    unittest.main()
