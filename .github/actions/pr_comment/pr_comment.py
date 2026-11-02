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

"""Keeps one pull request comment up to date, found by a hidden marker.

The comment that contains the marker is edited; when there's none, a new one is posted (unless
`--update-only`). Failing to comment is a warning, not an error: a pull request from a fork,
for example, gets a read-only token.

Usage:
  GH_TOKEN=... pr_comment.py --repository owner/name --pr-number 123 \\
      --marker my-report (--body TEXT | --body-file PATH) [--update-only]

Writes `result` (`created`, `updated`, `skipped` or `failed`) and `comment-id` to
$GITHUB_OUTPUT when it's set.
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

API = "https://api.github.com"
# GitHub rejects comment bodies over 65,536 characters; this leaves room for the notice.
MAX_BODY_CHARS = 65000
TRUNCATION_NOTICE = "\n\n*(Truncated: the comment was too long.)*"


def marker_line(marker):
  """The hidden line that identifies the comment."""
  return f"<!-- {marker} -->"


def comment_body(marker, body):
  """`body` with the marker line first, truncated to fit GitHub's limit."""
  text = f"{marker_line(marker)}\n{body}"
  if len(text) > MAX_BODY_CHARS:
    text = text[:MAX_BODY_CHARS - len(TRUNCATION_NOTICE)] + TRUNCATION_NOTICE
  return text


class GitHub:
  """The few GitHub REST calls this needs."""

  def __init__(self, token, repository):
    self.token = token
    self.repository = repository

  def request(self, method, path, body=None):
    """Sends a request; returns the decoded JSON response."""
    data = json.dumps({"body": body}).encode("utf-8") if body is not None else None
    request = urllib.request.Request(f"{API}{path}", data=data, method=method, headers={
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {self.token}",
        "Content-Type": "application/json",
        "User-Agent": "firebase-ios-sdk-pr-comment",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    with urllib.request.urlopen(request, timeout=30) as response:
      return json.loads(response.read().decode("utf-8") or "null")

  def comments(self, pr_number):
    """Every comment on the pull request, oldest first, a page at a time."""
    page = 1
    while True:
      batch = self.request(
          "GET", f"/repos/{self.repository}/issues/{pr_number}/comments?per_page=100&page={page}")
      yield from batch
      if len(batch) < 100:
        return
      page += 1

  def create_comment(self, pr_number, body):
    return self.request("POST", f"/repos/{self.repository}/issues/{pr_number}/comments", body)

  def update_comment(self, comment_id, body):
    return self.request("PATCH", f"/repos/{self.repository}/issues/comments/{comment_id}", body)


def update_or_create_comment(github, pr_number, marker, body, create=True):
  """Edits the comment with `marker`, or posts one when there's none and `create` is true.

  Returns `(result, comment_id)`: `created`, `updated` or `skipped` (no comment to update and
  `create` is false), and the comment's ID (None when skipped).
  """
  text = comment_body(marker, body)
  line = marker_line(marker)
  existing = next((c for c in github.comments(pr_number) if line in (c.get("body") or "")), None)
  if existing:
    github.update_comment(existing["id"], text)
    return "updated", existing["id"]
  if not create:
    return "skipped", None
  return "created", github.create_comment(pr_number, text)["id"]


def write_outputs(result, comment_id):
  """Writes the step outputs, when running in GitHub Actions."""
  path = os.environ.get("GITHUB_OUTPUT")
  if path:
    with open(path, "a", encoding="utf-8") as f:
      f.write(f"result={result}\ncomment-id={comment_id or ''}\n")


def parse_args(argv):
  parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
  parser.add_argument("--repository", required=True, help="owner/name")
  parser.add_argument("--pr-number", default="", help="empty: nothing to comment on; skipped")
  parser.add_argument("--marker", required=True, help="identifies the comment; keep it unique")
  body = parser.add_mutually_exclusive_group(required=True)
  body.add_argument("--body", help="the comment, in Markdown")
  body.add_argument("--body-file", help="a file holding the comment, in Markdown")
  parser.add_argument("--update-only", action="store_true",
                      help="only edit an existing comment; never post a new one")
  return parser.parse_args(argv)


def main(argv=None):
  args = parse_args(sys.argv[1:] if argv is None else argv)
  if not args.pr_number:
    print("No pull request to comment on; skipped.")
    write_outputs("skipped", None)
    return
  if args.body_file:
    with open(args.body_file, "r", encoding="utf-8", errors="replace") as f:
      body = f.read()
  else:
    body = args.body
  if not body.strip():
    # A usage mistake, unlike a failed API call, so it fails the step.
    sys.exit("::error::The comment is empty: pass a body or a non-empty body-file.")
  github = GitHub(os.environ.get("GH_TOKEN", ""), args.repository)
  try:
    result, comment_id = update_or_create_comment(github, args.pr_number, args.marker, body,
                                                  create=not args.update_only)
  except urllib.error.HTTPError as error:
    print(f"::warning::Couldn't comment on the pull request (HTTP {error.code}): {error.reason}")
    result, comment_id = "failed", None
  except (urllib.error.URLError, OSError, ValueError) as error:
    print(f"::warning::Couldn't comment on the pull request: {error}")
    result, comment_id = "failed", None
  print(f"Comment {result}" + (f": {comment_id}" if comment_id else "."))
  write_outputs(result, comment_id)


if __name__ == "__main__":
  main()
