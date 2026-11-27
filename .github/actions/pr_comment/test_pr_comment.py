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

"""Tests for pr_comment.py. Run: python3 -m unittest discover .github/actions/pr_comment"""

import io
import os
import tempfile
import unittest
import urllib.error
from contextlib import redirect_stdout
from unittest import mock

import pr_comment


class FakeGitHub:
  """Comments in memory, served in pages like the API."""

  def __init__(self, bodies=()):
    self.comments_by_id = {index + 1: body for index, body in enumerate(bodies)}
    self.created = []
    self.updated = []

  def comments(self, pr_number):
    for comment_id, body in self.comments_by_id.items():
      yield {"id": comment_id, "body": body}

  def create_comment(self, pr_number, body):
    comment_id = len(self.comments_by_id) + 1
    self.comments_by_id[comment_id] = body
    self.created.append(body)
    return {"id": comment_id}

  def update_comment(self, comment_id, body):
    self.comments_by_id[comment_id] = body
    self.updated.append((comment_id, body))


class UpdateOrCreateTests(unittest.TestCase):

  def test_creates_a_comment_with_the_marker_first(self):
    github = FakeGitHub()
    result = pr_comment.update_or_create_comment(github, "1", "report", "Hello")
    self.assertEqual(result, ("created", 1))
    self.assertEqual(github.created, ["<!-- report -->\nHello"])

  def test_updates_the_comment_with_the_marker(self):
    github = FakeGitHub(["unrelated", "<!-- report -->\nold", "<!-- other -->\nkeep"])
    result = pr_comment.update_or_create_comment(github, "1", "report", "new")
    self.assertEqual(result, ("updated", 2))
    self.assertEqual(github.updated, [(2, "<!-- report -->\nnew")])
    self.assertEqual(github.created, [])

  def test_a_marker_only_matches_as_a_whole(self):
    github = FakeGitHub(["<!-- report-extra -->\nother"])
    result = pr_comment.update_or_create_comment(github, "1", "report", "new")
    self.assertEqual(result, ("created", 2))

  def test_update_only_skips_without_a_comment(self):
    github = FakeGitHub(["unrelated"])
    result = pr_comment.update_or_create_comment(github, "1", "report", "new", create=False)
    self.assertEqual(result, ("skipped", None))
    self.assertEqual(github.created, [])

  def test_update_only_still_updates(self):
    github = FakeGitHub(["<!-- report -->\nold"])
    result = pr_comment.update_or_create_comment(github, "1", "report", "new", create=False)
    self.assertEqual(result, ("updated", 1))

  def test_a_comment_without_a_body_is_ignored(self):
    github = FakeGitHub([None])
    result = pr_comment.update_or_create_comment(github, "1", "report", "new")
    self.assertEqual(result, ("created", 2))


class CommentBodyTests(unittest.TestCase):

  def test_a_long_body_is_truncated_to_the_limit(self):
    body = pr_comment.comment_body("report", "x" * 100_000)
    self.assertEqual(len(body), pr_comment.MAX_BODY_CHARS)
    self.assertTrue(body.startswith("<!-- report -->\n"))
    self.assertTrue(body.endswith(pr_comment.TRUNCATION_NOTICE))

  def test_a_short_body_is_unchanged(self):
    self.assertEqual(pr_comment.comment_body("report", "short"), "<!-- report -->\nshort")


class PaginationTests(unittest.TestCase):

  def test_reads_every_page(self):
    pages = [[{"id": n} for n in range(100)], [{"id": 100}]]
    github = pr_comment.GitHub("token", "owner/name")
    with mock.patch.object(github, "request", side_effect=pages) as request:
      self.assertEqual(len(list(github.comments("1"))), 101)
    self.assertEqual(request.call_count, 2)
    self.assertIn("page=2", request.call_args_list[1].args[1])


class MainTests(unittest.TestCase):

  def run_main(self, argv, github=None):
    """Runs `main`, returning its stdout and outputs."""
    with tempfile.TemporaryDirectory() as directory:
      outputs = os.path.join(directory, "outputs")
      stdout = io.StringIO()
      with mock.patch.dict(os.environ, {"GITHUB_OUTPUT": outputs, "GH_TOKEN": "token"}), \
          mock.patch.object(pr_comment, "GitHub", return_value=github or FakeGitHub()), \
          redirect_stdout(stdout):
        pr_comment.main(argv)
      with open(outputs, encoding="utf-8") as f:
        return stdout.getvalue(), f.read()

  def test_without_a_pull_request_it_skips(self):
    _, outputs = self.run_main(["--repository", "o/r", "--marker", "m", "--body", "b"])
    self.assertEqual(outputs, "result=skipped\ncomment-id=\n")

  def test_reads_the_body_file(self):
    github = FakeGitHub()
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
      f.write("From a file")
    try:
      _, outputs = self.run_main(["--repository", "o/r", "--pr-number", "1", "--marker", "m",
                                  "--body-file", f.name], github)
    finally:
      os.remove(f.name)
    self.assertEqual(github.created, ["<!-- m -->\nFrom a file"])
    self.assertEqual(outputs, "result=created\ncomment-id=1\n")

  def test_an_empty_body_fails(self):
    with self.assertRaises(SystemExit):
      self.run_main(["--repository", "o/r", "--pr-number", "1", "--marker", "m", "--body", " "])

  def test_an_api_error_is_a_warning(self):
    github = FakeGitHub()
    github.comments = mock.Mock(side_effect=urllib.error.HTTPError(
        "url", 403, "Forbidden", {}, None))
    stdout, outputs = self.run_main(["--repository", "o/r", "--pr-number", "1", "--marker", "m",
                                     "--body", "b"], github)
    self.assertIn("::warning::Couldn't comment on the pull request (HTTP 403)", stdout)
    self.assertEqual(outputs, "result=failed\ncomment-id=\n")


if __name__ == "__main__":
  unittest.main()
