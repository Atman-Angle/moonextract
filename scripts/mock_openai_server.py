#!/usr/bin/env python3
"""Minimal OpenAI-compatible server for offline MoonExtract end-to-end tests."""
from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CONTRACT_CLAIMS = {
    "claims": [
        {
            "field": "party",
            "value": "上海晨星科技有限公司",
            "quote": "上海晨星科技有限公司",
        },
        {
            "field": "party",
            "value": "北京远山数据有限公司",
            "quote": "北京远山数据有限公司",
        },
        {
            "field": "amount",
            "value": "120000 元",
            "quote": "120,000 元",
        },
        {
            "field": "notice_days",
            "value": "30 日",
            "quote": "30 日",
            "context": "终止通知",
        },
    ]
}

TICKET_CLAIMS = {
    "claims": [
        {"field": "service", "value": "支付网关", "quote": "支付网关"},
        {"field": "severity", "value": "P1", "quote": "P1"},
        {"field": "root_cause", "value": "证书过期", "quote": "证书过期"},
        {"field": "region", "value": "华东", "quote": "华东"},
    ]
}


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        body_bytes = self.rfile.read(length)
        body_text = body_bytes.decode("utf-8", errors="ignore")
        if self.path.rstrip("/") not in {"/v1/chat/completions", "/chat/completions"}:
            self.send_error(404)
            return
        claims = TICKET_CLAIMS if "SUP-" in body_text else CONTRACT_CLAIMS
        content = json.dumps(claims, ensure_ascii=False, separators=(",", ":"))
        payload = {
            "id": "chatcmpl-moonextract-mock",
            "object": "chat.completion",
            "created": 0,
            "model": "moonextract-mock",
            "choices": [
                {
                    "index": 0,
                    "message": {"role": "assistant", "content": content},
                    "finish_reason": "stop",
                }
            ],
            "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2},
        }
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, _format: str, *_args: object) -> None:
        return


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=18765)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
