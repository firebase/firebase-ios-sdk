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

import contextlib
import io
import json
import pathlib
import tempfile
import unittest

import test_server_diagnostics

_POLICY = {
    "allowedRequestHeaders": ["Content-Type", "Test-Name"],
    "allowedResponseHeaders": ["Content-Type", "Server"],
    "strippedResponseHeaders": ["Date", "Server-Timing"],
}


def _recording(request_headers, response_headers, text="Hello"):
    return {
        "recordID": "Suite/test/backend",
        "interactions": [
            {
                "request": {
                    "method": "POST",
                    "url": "/v1beta/models/m:generateContent",
                    "headers": request_headers,
                    "bodySegments": [{"contents": []}],
                },
                "shaSum": "abc",
                "response": {
                    "statusCode": 200,
                    "headers": response_headers,
                    "bodySegments": [{"text": text}],
                },
            }
        ],
    }


class TestAudit(unittest.TestCase):

    def setUp(self):
        self._directory = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self._directory.name)
        self.recordings = self.root / "recordings"
        self.recordings.mkdir()
        self.policy = self.root / "recording-policy.json"
        self.policy.write_text(json.dumps(_POLICY), encoding="utf-8")

    def tearDown(self):
        self._directory.cleanup()

    def _write(self, name, record):
        path = self.recordings / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            test_server_diagnostics._serialize_like_go(record), encoding="utf-8"
        )
        return path

    def test_allowed_headers_pass(self):
        self._write(
            "Suite/test/backend.json",
            _recording(
                {"Content-Type": "application/json", "Test-Name": "Suite/test"},
                {"Content-Type": "text/event-stream", "Server": "scaffolding"},
            ),
        )

        count, violations = test_server_diagnostics.audit(
            self.recordings, self.policy
        )

        self.assertEqual(count, 1)
        self.assertEqual(violations, [])

    def test_unexpected_request_header_is_reported_without_its_value(self):
        self._write(
            "a.json",
            _recording({"Authorization": "Bearer ya29.secret-token"}, {}),
        )

        _, violations = test_server_diagnostics.audit(
            self.recordings, self.policy
        )

        self.assertEqual(
            violations,
            ["a.json: request #1 has unexpected request header Authorization"],
        )
        self.assertNotIn("ya29", violations[0])

    def test_request_headers_are_compared_case_insensitively(self):
        self._write(
            "a.json",
            _recording(
                {"content-type": "application/json", "x-goog-api-key": "key"},
                {},
            ),
        )

        _, violations = test_server_diagnostics.audit(
            self.recordings, self.policy
        )

        self.assertEqual(
            violations,
            ["a.json: request #1 has unexpected request header x-goog-api-key"],
        )

    def test_unexpected_response_header_is_reported(self):
        self._write("a.json", _recording({}, {"Set-Cookie": "session=secret"}))

        _, violations = test_server_diagnostics.audit(
            self.recordings, self.policy
        )

        self.assertEqual(
            violations,
            ["a.json: response #1 has unexpected response header Set-Cookie"],
        )

    def test_noisy_response_header_is_reported_without_fix(self):
        path = self._write("a.json", _recording({}, {"Date": "Tue, 13 Oct"}))
        original = path.read_text(encoding="utf-8")

        _, violations = test_server_diagnostics.audit(
            self.recordings, self.policy
        )

        self.assertEqual(len(violations), 1)
        self.assertIn("noisy response header Date", violations[0])
        self.assertEqual(path.read_text(encoding="utf-8"), original)

    def test_fix_strips_noisy_response_headers(self):
        path = self._write(
            "a.json",
            _recording(
                {},
                {
                    "Date": "Tue, 13 Oct",
                    "Server": "scaffolding",
                    "Server-Timing": "dur=1",
                },
            ),
        )

        _, violations = test_server_diagnostics.audit(
            self.recordings, self.policy, fix=True
        )

        self.assertEqual(violations, [])
        headers = json.loads(path.read_text(encoding="utf-8"))["interactions"][
            0
        ]["response"]["headers"]
        self.assertEqual(headers, {"Server": "scaffolding"})

    def test_fix_only_removes_stripped_header_lines(self):
        record = _recording(
            {}, {"Date": "Tue, 13 Oct", "Server": "s"}, "<a & b>"
        )
        path = self._write("a.json", record)
        original_lines = path.read_text(encoding="utf-8").splitlines()

        test_server_diagnostics.audit(self.recordings, self.policy, fix=True)

        fixed = path.read_text(encoding="utf-8")
        self.assertEqual(
            fixed.splitlines(),
            [line for line in original_lines if '"Date"' not in line],
        )
        self.assertIn("\\u003ca \\u0026 b\\u003e", fixed)

    def test_fix_leaves_compliant_recordings_untouched(self):
        path = self.recordings / "a.json"
        original = '{\n  "interactions": []\n}'
        path.write_text(original, encoding="utf-8")

        test_server_diagnostics.audit(self.recordings, self.policy, fix=True)

        self.assertEqual(path.read_text(encoding="utf-8"), original)


class TestExplain(unittest.TestCase):

    def setUp(self):
        self._directory = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self._directory.name)
        self.recordings = self.root / "recordings"
        (self.recordings / "Suite").mkdir(parents=True)
        (self.recordings / "Suite" / "test.json").write_text(
            json.dumps(_recording({"Content-Type": "application/json"}, {})),
            encoding="utf-8",
        )
        self.config = self.root / "test-server.yml"
        self.config.write_text(
            "endpoints:\n  - redact_request_headers:\n      - X-Goog-Api-Key\n",
            encoding="utf-8",
        )
        self.log = self.root / "captured-requests.jsonl"

    def tearDown(self):
        self._directory.cleanup()

    def _capture(self, status, response_body, body='{"contents": []}'):
        entry = {
            "testName": "Suite/test",
            "method": "POST",
            "url": "/v1beta/models/m:generateContent",
            "headers": {
                "Content-Type": "application/json",
                "X-Goog-Api-Key": "k",
            },
            "body": body,
            "status": status,
            "responseBody": response_body,
        }
        with self.log.open("a", encoding="utf-8") as log:
            log.write(json.dumps(entry) + "\n")

    def test_body_mismatch_is_explained(self):
        self._capture(
            500,
            "Error loading response: response with shaSum x not found",
            body='{"contents": [{"role": "user"}]}',
        )

        with contextlib.redirect_stdout(io.StringIO()) as output:
            explained = test_server_diagnostics.explain(
                self.log, self.recordings, self.config
            )

        self.assertEqual(explained, 1)
        self.assertIn("Request #1", output.getvalue())
        self.assertIn('+      "role": "user"', output.getvalue())

    def test_recorded_error_response_is_not_unmatched(self):
        self._capture(403, '{"error": {"code": 403}}')

        with contextlib.redirect_stdout(io.StringIO()):
            explained = test_server_diagnostics.explain(
                self.log, self.recordings, self.config
            )

        self.assertEqual(explained, 0)


if __name__ == "__main__":
    unittest.main()
