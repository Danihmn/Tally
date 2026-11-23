import tomllib
import unittest
from pathlib import Path

from fastapi.testclient import TestClient

from presentation.app import API_VERSION, app


class TestApiVersion(unittest.TestCase):
    def test_api_version_comes_from_pyproject(self):
        pyproject = Path(__file__).resolve().parents[2] / "pyproject.toml"
        with pyproject.open("rb") as file:
            expected = tomllib.load(file)["project"]["version"]

        self.assertEqual(API_VERSION, expected)
        self.assertEqual(app.version, expected)

    def test_openapi_shows_the_api_version(self):
        response = TestClient(app).get("/openapi.json")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["info"]["version"], API_VERSION)


if __name__ == "__main__":
    unittest.main()
