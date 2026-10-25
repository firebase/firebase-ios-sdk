#!/usr/bin/env python3

# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Diagnostics and checks for test-server recordings.

test-server answers an unrecorded request with HTTP 500 and a hash, without
saying which part of the request changed. This tool has these commands:

  proxy    Forwards requests to test-server and logs each request and response
           status as JSON lines.
  explain  Compares the first unmatched request of each test in a proxy log
           with the recorded request it should have matched.
  audit    Checks that recordings only contain headers allowed by the recording
           policy, and optionally strips noisy response headers.

Used by `scripts/test-server.sh`; only the Python standard library is required.
"""

import argparse
import collections
import difflib
import hashlib
import http.client
import http.server
import json
import os
import pathlib
import re
import sys
import threading

# Headers that never reach test-server's request hash.
_TRANSPORT_HEADERS = {"Host"}
_HOP_BY_HOP_HEADERS = {"Connection", "Content-Length", "Transfer-Encoding"}
_MAX_STRING_LENGTH = 120
_MAX_DIFF_LINES = 80


def _canonical_header(name):
    """Returns a header name in Go's canonical form (e.g. `X-Goog-Api-Key`)."""
    return "-".join(
        part[:1].upper() + part[1:].lower() for part in name.split("-")
    )


# MARK: - Proxy


def _make_handler(upstream_port, log_file, lock):
    class ProxyHandler(http.server.BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def _forward(self):
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length) if length else b""
            connection = http.client.HTTPConnection(
                "127.0.0.1", upstream_port, timeout=60
            )
            connection.request(
                self.command, self.path, body, headers=dict(self.headers)
            )
            response = connection.getresponse()
            response_body = response.read()
            connection.close()

            if self.path != "/test-server/health":
                entry = {
                    "testName": self.headers.get("Test-Name", ""),
                    "method": self.command,
                    "url": self.path,
                    "headers": {
                        _canonical_header(k): v for k, v in self.headers.items()
                    },
                    "body": body.decode("utf-8", errors="replace"),
                    "status": response.status,
                    "responseBody": response_body.decode(
                        "utf-8", errors="replace"
                    )[:2000],
                }
                with lock:
                    log_file.write(json.dumps(entry) + "\n")
                    log_file.flush()

            self.send_response(response.status)
            for name, value in response.getheaders():
                if _canonical_header(name) not in _HOP_BY_HOP_HEADERS:
                    self.send_header(name, value)
            self.send_header("Content-Length", str(len(response_body)))
            self.end_headers()
            self.wfile.write(response_body)

        do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = _forward

        def log_message(self, format, *args):
            pass

    return ProxyHandler


def run_proxy(listen_pairs, log_path):
    """Forwards each `listen:upstream` port pair until terminated."""
    lock = threading.Lock()
    log_file = open(log_path, "a", encoding="utf-8")
    servers = []
    for pair in listen_pairs:
        listen_port, upstream_port = (int(port) for port in pair.split(":"))
        handler = _make_handler(upstream_port, log_file, lock)
        servers.append(
            http.server.ThreadingHTTPServer(("", listen_port), handler)
        )
    threads = [
        threading.Thread(target=server.serve_forever, daemon=True)
        for server in servers
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()


# MARK: - Explain


def _redacted_headers(config_path):
    """Returns the header names under `redact_request_headers` in the config."""
    names = set()
    in_list = False
    for line in (
        pathlib.Path(config_path).read_text(encoding="utf-8").splitlines()
    ):
        stripped = line.strip()
        if stripped.startswith("redact_request_headers:"):
            in_list = True
            continue
        if in_list:
            match = re.fullmatch(r"-\s*([A-Za-z0-9-]+)", stripped)
            if match:
                names.add(_canonical_header(match.group(1)))
            elif stripped and not stripped.startswith("#"):
                in_list = False
    return names


def _shorten(value):
    """Shortens long strings (e.g. thought signatures), keeping them unique."""
    if isinstance(value, dict):
        return {key: _shorten(item) for key, item in sorted(value.items())}
    if isinstance(value, list):
        return [_shorten(item) for item in value]
    if isinstance(value, str) and len(value) > _MAX_STRING_LENGTH:
        digest = hashlib.sha256(value.encode("utf-8")).hexdigest()[:12]
        return f"{value[:60]}… <{len(value)} chars, sha256 {digest}>"
    return value


def _pretty_lines(value):
    return json.dumps(
        _shorten(value), indent=2, ensure_ascii=False
    ).splitlines()


def _parse_json(text):
    try:
        return json.loads(text) if text else {}
    except json.JSONDecodeError:
        return {"<non-JSON body>": text}


def _explain_mismatch(request, recorded, redacted):
    """Returns readable differences between an incoming and recorded request."""
    differences = []
    if request["method"] != recorded.get("method"):
        differences.append(
            f"Method: recorded {recorded.get('method')}, "
            f"got {request['method']}"
        )
    if request["url"] != recorded.get("url"):
        differences.append(
            f"URL:\n  recorded {recorded.get('url')}\n"
            f"  got      {request['url']}"
        )

    incoming_headers = {
        name: value
        for name, value in request["headers"].items()
        if name not in redacted and name not in _TRANSPORT_HEADERS
    }
    recorded_headers = recorded.get("headers") or {}
    for name in sorted(set(incoming_headers) | set(recorded_headers)):
        if incoming_headers.get(name) != recorded_headers.get(name):
            differences.append(
                f"Header {name}: recorded {recorded_headers.get(name)!r}, "
                f"got {incoming_headers.get(name)!r}"
            )

    recorded_body = (recorded.get("bodySegments") or [{}])[0] or {}
    incoming_body = _parse_json(request["body"])
    if recorded_body != incoming_body:
        diff = list(
            difflib.unified_diff(
                _pretty_lines(recorded_body),
                _pretty_lines(incoming_body),
                fromfile="recorded body",
                tofile="request body",
                lineterm="",
            )
        )
        if len(diff) > _MAX_DIFF_LINES:
            diff = diff[:_MAX_DIFF_LINES] + [
                f"… {len(diff) - _MAX_DIFF_LINES} more lines"
            ]
        differences.append("Body:\n" + "\n".join(diff))
    return differences


def _is_unmatched(request):
    """Returns whether test-server rejected the request for lack of a recording.

    Recorded error responses (for example, a 403 for a missing API key) are
    replayed with their original status, so only test-server's own error counts.
    """
    return request["status"] == 500 and request.get(
        "responseBody", ""
    ).startswith("Error loading response")


def explain(log_path, recordings_dir, config_path):
    """Explains each test with an unmatched request; returns the test count."""
    redacted = _redacted_headers(config_path)
    requests_by_test = collections.OrderedDict()
    log = pathlib.Path(log_path)
    for line in (
        log.read_text(encoding="utf-8").splitlines() if log.exists() else []
    ):
        entry = json.loads(line)
        requests_by_test.setdefault(entry["testName"], []).append(entry)

    explained = 0
    for test_name, requests in requests_by_test.items():
        index = next(
            (i for i, request in enumerate(requests) if _is_unmatched(request)),
            None,
        )
        if index is None:
            continue
        explained += 1
        request = requests[index]
        print(f"\n✘ {test_name or '<no Test-Name header>'}")
        print(
            f"  Request #{index + 1} ({request['method']} {request['url']}) "
            "was not matched."
        )

        recording_path = pathlib.Path(recordings_dir) / (
            test_name.replace(" ", "_") + ".json"
        )
        if not test_name or not recording_path.exists():
            print(
                f"  No recording at {os.path.relpath(recording_path)}. "
                "Record it with `scripts/test-server.sh record`."
            )
            continue
        interactions = json.loads(
            recording_path.read_text(encoding="utf-8")
        ).get("interactions", [])
        if index >= len(interactions):
            print(
                f"  The recording only has {len(interactions)} request(s); "
                "the test sent more."
            )
            continue

        differences = _explain_mismatch(
            request, interactions[index]["request"], redacted
        )
        if differences:
            print(
                f"  Differences from recorded request #{index + 1} in "
                f"{recording_path.name}:"
            )
            for difference in differences:
                print("  " + difference.replace("\n", "\n  "))
        else:
            print(
                f"  The request matches recorded request #{index + 1}, so the "
                "mismatch is in the request chain: an earlier request differs, "
                "or the test ran twice against one replay server."
            )
    if explained:
        print(
            "\nIf these changes are intentional, re-record with "
            "`scripts/test-server.sh record <filter>` and review the "
            "recording diff."
        )
    return explained


# MARK: - Audit

_POLICY_KEYS = (
    "allowedRequestHeaders",
    "allowedResponseHeaders",
    "strippedResponseHeaders",
)


def _load_policy(policy_path):
    """Returns the recording policy with header names in canonical form."""
    policy = json.loads(pathlib.Path(policy_path).read_text(encoding="utf-8"))
    return {
        key: {_canonical_header(name) for name in policy.get(key, [])}
        for key in _POLICY_KEYS
    }


def _serialize_like_go(record):
    """Serializes a recording like test-server's Go `json.MarshalIndent`.

    Go escapes `<`, `>`, and `&` in strings; matching it keeps rewrites limited
    to the headers that were removed.
    """
    text = json.dumps(record, indent=2, ensure_ascii=False)
    return (
        text.replace("<", "\\u003c")
        .replace(">", "\\u003e")
        .replace("&", "\\u0026")
    )


def audit(recordings_dir, policy_path, fix=False):
    """Checks recorded headers against the recording policy.

    Only header names are reported, never values, so a leaked credential isn't
    copied into logs.

    Args:
      recordings_dir: The test-server recordings directory.
      policy_path: The path to `recording-policy.json`.
      fix: Whether to strip `strippedResponseHeaders` instead of reporting them.

    Returns:
      A tuple of the number of recordings audited and a list of violations.
    """
    policy = _load_policy(policy_path)
    root = pathlib.Path(recordings_dir)
    paths = sorted(root.rglob("*.json"))
    violations = []
    for path in paths:
        record = json.loads(path.read_text(encoding="utf-8"))
        relative = path.relative_to(root)
        changed = False
        interactions = record.get("interactions") or []
        for index, interaction in enumerate(interactions, start=1):
            request = interaction.get("request") or {}
            for name in sorted(request.get("headers") or {}):
                if (
                    _canonical_header(name)
                    not in policy["allowedRequestHeaders"]
                ):
                    violations.append(
                        f"{relative}: request #{index} has unexpected request "
                        f"header {name}"
                    )

            response_headers = (interaction.get("response") or {}).get(
                "headers"
            ) or {}
            for name in sorted(response_headers):
                canonical = _canonical_header(name)
                if canonical in policy["strippedResponseHeaders"]:
                    if fix:
                        del response_headers[name]
                        changed = True
                    else:
                        violations.append(
                            f"{relative}: response #{index} still has noisy "
                            f"response header {name}; run "
                            "`scripts/test-server.sh audit --fix`"
                        )
                elif canonical not in policy["allowedResponseHeaders"]:
                    violations.append(
                        f"{relative}: response #{index} has unexpected "
                        f"response header {name}"
                    )
        if changed:
            path.write_text(_serialize_like_go(record), encoding="utf-8")
    return len(paths), violations


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    subparsers = parser.add_subparsers(dest="command", required=True)

    proxy_parser = subparsers.add_parser("proxy")
    proxy_parser.add_argument(
        "--listen", action="append", required=True, metavar="PORT:UPSTREAM"
    )
    proxy_parser.add_argument("--log", required=True)

    explain_parser = subparsers.add_parser("explain")
    explain_parser.add_argument("--log", required=True)
    explain_parser.add_argument("--recordings", required=True)
    explain_parser.add_argument("--config", required=True)

    audit_parser = subparsers.add_parser("audit")
    audit_parser.add_argument("--recordings", required=True)
    audit_parser.add_argument("--policy", required=True)
    audit_parser.add_argument(
        "--fix",
        action="store_true",
        help="strip noisy response headers instead of reporting them",
    )

    args = parser.parse_args()
    if args.command == "proxy":
        run_proxy(args.listen, args.log)
    elif args.command == "explain":
        explained = explain(args.log, args.recordings, args.config)
        if not explained:
            print("No unmatched requests were captured.")
    else:
        count, violations = audit(args.recordings, args.policy, fix=args.fix)
        for violation in violations:
            print(f"✘ {violation}")
        if violations:
            print(
                f"\n{len(violations)} header policy violation(s) in {count} "
                "recording(s). Don't commit these recordings until each header "
                "is redacted in test-server.yml, stripped, or allowed in "
                "recording-policy.json."
            )
            return 1
        print(f"Audited {count} recording(s): all headers are allowed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
