import json
import os
from pathlib import Path

INDEX_HTML = (Path(__file__).parent / "static" / "index.html").read_text(encoding="utf-8")


def handler(event, context):
    """API Gateway REST (proxy) entry point: "/" serves the page, "/api/*" returns JSON."""
    path = event.get("path") or "/"

    if path in ("/", "/index.html"):
        return {
            "statusCode": 200,
            "headers": {"content-type": "text/html; charset=utf-8"},
            "body": INDEX_HTML,
        }

    if path.startswith("/api/"):
        body = {
            "service": "cloudone-api",
            "environment": os.environ.get("ENVIRONMENT", "unknown"),
            "method": event.get("httpMethod"),
            "path": path,
        }
        return {
            "statusCode": 200,
            "headers": {"content-type": "application/json"},
            "body": json.dumps(body),
        }

    return {
        "statusCode": 404,
        "headers": {"content-type": "application/json"},
        "body": json.dumps({"error": "not found", "path": path}),
    }
