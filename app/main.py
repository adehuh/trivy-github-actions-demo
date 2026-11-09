"""Tiny demo shop API (stdlib only) used to exercise the CI pipeline."""
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

PRODUCTS = {"apple": {"price": 10000, "stock": 5}, "mango": {"price": 15000, "stock": 0}}


def calculate_total(price: int, qty: int, discount_pct: int = 0) -> int:
    """P0: payment total. Rejects invalid input instead of guessing."""
    if price < 0 or qty <= 0 or not 0 <= discount_pct <= 100:
        raise ValueError("invalid price, quantity or discount")
    return price * qty * (100 - discount_pct) // 100


def reserve_stock(product: str, qty: int) -> int:
    """P0: stock calculation. Returns remaining stock or raises."""
    item = PRODUCTS.get(product)
    if item is None:
        raise KeyError(product)
    if qty > item["stock"]:
        raise ValueError("insufficient stock")
    return item["stock"] - qty


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, body: dict) -> None:
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):  # noqa: N802
        if self.path == "/healthz":
            self._send(200, {"status": "ok"})
        elif self.path == "/products":
            self._send(200, PRODUCTS)
        else:
            self._send(404, {"error": "not found"})

    def log_message(self, *args):  # keep CI logs quiet
        pass


def main() -> None:
    port = int(os.environ.get("PORT", "8080"))
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
