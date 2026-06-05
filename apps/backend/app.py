from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse
from datetime import datetime, timezone
import json
import os


CLUSTERS = [
    {
        "name": "cloudopshub-prod",
        "environment": "production",
        "region": "us-east-1",
        "zones": ["us-east-1a", "us-east-1b"],
        "nodes": 4,
        "status": "healthy",
        "availability": "99.98%",
        "workloads": 18,
    },
    {
        "name": "cloudopshub-staging",
        "environment": "staging",
        "region": "us-east-1",
        "zones": ["us-east-1a", "us-east-1b"],
        "nodes": 2,
        "status": "healthy",
        "availability": "99.91%",
        "workloads": 12,
    },
    {
        "name": "cloudopshub-dev",
        "environment": "development",
        "region": "us-east-1",
        "zones": ["us-east-1a", "us-east-1b"],
        "nodes": 2,
        "status": "healthy",
        "availability": "99.86%",
        "workloads": 9,
    },
]

PIPELINES = [
    {
        "name": "frontend-release",
        "branch": "main",
        "stage": "production",
        "status": "passed",
        "image": "docker.io/fabulousjeff2009/cloudopshub-frontend:latest",
        "duration": "4m 12s",
    },
    {
        "name": "backend-release",
        "branch": "main",
        "stage": "production",
        "status": "passed",
        "image": "docker.io/fabulousjeff2009/cloudopshub-backend:latest",
        "duration": "3m 48s",
    },
    {
        "name": "db-infra-plan",
        "branch": "fix-push",
        "stage": "terraform",
        "status": "passed",
        "image": "rds-postgres-multi-az",
        "duration": "2m 21s",
    },
]

INCIDENTS = [
    {
        "id": "INC-1042",
        "service": "frontend",
        "severity": "low",
        "status": "resolved",
        "summary": "Public endpoint latency briefly exceeded SLO.",
    },
    {
        "id": "INC-1041",
        "service": "backend",
        "severity": "info",
        "status": "watching",
        "summary": "New production rollout completed and is under observation.",
    },
]


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def platform_summary():
    healthy_clusters = sum(1 for cluster in CLUSTERS if cluster["status"] == "healthy")
    return {
        "service": "cloudopshub-backend",
        "status": "ok",
        "generatedAt": now_iso(),
        "summary": {
            "clusters": len(CLUSTERS),
            "healthyClusters": healthy_clusters,
            "environments": ["dev", "staging", "prod"],
            "activePipelines": len(PIPELINES),
            "openIncidents": sum(1 for incident in INCIDENTS if incident["status"] != "resolved"),
            "database": "RDS PostgreSQL Multi-AZ",
        },
    }


ROUTES = {
    "/": platform_summary,
    "/healthz": platform_summary,
    "/api/summary": platform_summary,
    "/api/clusters": lambda: {"clusters": CLUSTERS, "generatedAt": now_iso()},
    "/api/pipelines": lambda: {"pipelines": PIPELINES, "generatedAt": now_iso()},
    "/api/incidents": lambda: {"incidents": INCIDENTS, "generatedAt": now_iso()},
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        handler = ROUTES.get(path)

        if handler is None:
            self.send_json({"error": "not_found", "path": path}, status=404)
            return

        self.send_json(handler())

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_common_headers()
        self.end_headers()

    def send_json(self, payload, status=200):
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_common_headers()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_common_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def log_message(self, format, *args):
        print("%s - %s" % (self.address_string(), format % args))


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()
