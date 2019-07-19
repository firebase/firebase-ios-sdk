#!/usr/bin/env python

# Copyright 2019 Google
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

"""Converts github flavored markdown changelogs to release notes.
"""

import argparse
import re
import subprocess


def main():
  local_repo = find_local_repo()

  parser = argparse.ArgumentParser(description='Create release notes.')
  parser.add_argument('--repo', '-r', default=local_repo,
                      help='Specify which GitHub repo is local.')
  parser.add_argument('changelog',
                      help='The CHANGELOG.md file to parse')
  args = parser.parse_args()

  renderer = Renderer(args.repo)
  translator = Translator(renderer)

  process_changelog(translator, args.changelog)


def find_local_repo():
  url = subprocess.check_output(['git', 'config', '--get', 'remote.origin.url'])

  # ssh or https style URL
  m = re.match(r'^(?:git@github\.com:|https://github\.com/)(.*)\.git$', url)
  if m:
    return m.group(1)

  raise LookupError('Can\'t figure local repo from remote URL %s' % url)


class Renderer(object):

  def __init__(self, local_repo):
    self.local_repo = local_repo

  def bullet(self, spacing):
    """Renders a bullet in a list.

    All bulleted lists in devsite are '*' style.
    """
    return '%s* ' + spacing

  def change_type(self, tag):
    """Renders a change type tag as the appropriate double-braced macro.

    That is "[fixed]" is rendered as "{{fixed}}".
    """
    return '{{%s}}' % tag

  def url(self, url):
    m = re.match(r'^(?:https:)?(//github.com/(.*)/issues/(\d+))$', url)
    if m:
      link = m.group(1)
      repo = m.group(2)
      issue = m.group(3)

      if repo == self.local_repo:
        text = '#' + issue
      else:
        text = repo + '#' + issue

      return '[%s](%s)' % (text, link)

    return url

  def local_issue_link(self, issue):
    """Renders a local issue link as a proper markdown URL.

    Transforms (#1234) into
    ([#1234](//github.com/firebase/firebase-ios-sdk/issues/1234)).
    """
    link = '//github.com/%s/issues/%s' % (self.local_repo, issue)
    return '([#%s](%s))' % (issue, link)

  def text(self, text):
    """Passes through any other text."""
    return text


class Translator(object):
  def __init__(self, renderer):
    self.renderer = renderer

  def translate(self, text):
    result = ''
    while text:
      for key in self.rules:
        rule = getattr(self, key)
        m = rule.match(text)
        if not m:
          continue

        callback = getattr(self, 'parse_' + key)
        callback_result = callback(m)
        result += callback_result

        text = text[len(m.group(0)):]
        break

    return result

  bullet = re.compile(
      r'^(\s*)[*+-] '
  )

  def parse_bullet(self, m):
    return self.renderer.bullet(m.group(1))

  change_type = re.compile(
      r'\['           # opening square bracket
      r'(\w+)'        # tag word (like "feature" or "changed"
      r'\]'           # closing square bracket
      r'(?!\()'       # not followed by opening paren (that would be a link)
  )

  def parse_change_type(self, m):
    return self.renderer.change_type(m.group(1))

  url = re.compile(r'^(https?://[^\s<]+[^<.,:;"\')\]\s])')

  def parse_url(self, m):
    return self.renderer.url(m.group(1))

  local_issue_link = re.compile(
      r'\('           # opening paren
      r'#(\d+)'       # hash and issue number
      r'\)'           # closing paren
  )

  def parse_local_issue_link(self, m):
    return self.renderer.local_issue_link(m.group(1))

  text = re.compile(
      r'^[\s\S]+?(?=[(\[]|https?://|$)'
  )

  def parse_text(self, m):
    return self.renderer.text(m.group(0))

  rules = ['bullet', 'change_type', 'url', 'local_issue_link', 'text']


def process_changelog(translator, filename):
  with open(filename, 'r') as fd:
    text = fd.read()
    result = translator.translate(text)
    print(result)


def read_lines(filename):
  with open(filename, 'r') as fd:
    return [line.rstrip() for line in fd.readlines()]


if __name__ == '__main__':
  main()