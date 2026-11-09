"""Starts the real HTTP server on a random port and calls it."""
import json
import threading
import unittest
import urllib.error
import urllib.request
from http.server import HTTPServer

from app.main import Handler


class TestHttp(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(("127.0.0.1", 0), Handler)
        cls.base = f"http://127.0.0.1:{cls.server.server_port}"
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def get(self, path):
        with urllib.request.urlopen(self.base + path, timeout=5) as r:
            return r.status, json.loads(r.read())

    def test_health(self):
        self.assertEqual(self.get("/healthz"), (200, {"status": "ok"}))

    def test_products(self):
        status, body = self.get("/products")
        self.assertEqual(status, 200)
        self.assertIn("apple", body)

    def test_404(self):
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            self.get("/nope")
        self.assertEqual(ctx.exception.code, 404)


if __name__ == "__main__":
    unittest.main()
