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
import mistune
import re
import subprocess
import textwrap

from pprint import pprint as pp


def main():
  local_repo = find_local_repo()

  parser = argparse.ArgumentParser(description='Create release notes.')
  parser.add_argument('--repo', '-r', default=local_repo,
                      help='Specify which GitHub repo is local.')
  parser.add_argument('changelog',
                      help='The CHANGELOG.md file to parse')
  args = parser.parse_args()

  renderer = Renderer(args.repo)

  inline = ChangelogInlineLexer(renderer)
  inline.enable_changelog()

  md = mistune.Markdown(renderer=renderer, inline=inline)
  process_changelog(md, args.changelog)


def find_local_repo():
  url = subprocess.check_output(['git', 'config', '--get', 'remote.origin.url'])

  # ssh style URL
  m = re.match(r'^git@github.com:(.*)\.git$', url)
  if m:
    return m.group(1)

  # https style URL
  m = re.match(r'^https://github.com/(.*).git$')
  if m:
    return m.group(1)

  raise LookupError('Can\'t figure local repo from remote URL %s' % url)


class ChangelogInlineLexer(mistune.InlineLexer):
  """Recognizes certain additional patterns within the changelog.

  This extends Mistune's lexer for inline elements (those within a block) to add
  the following lexical elements:

    - support for change-type tags "[fixed]", "[changed]", etc.
    - support for expanding short issue references "(#2987)".

  These are translated to the equivalent form for docsite.
  """

  def enable_changelog(self):
    self.rules.change_type = re.compile(
        r'\['           # opening square bracket
        r'(\w+)'        # tag word (like "feature" or "changed"
        r'\]'           # closing square bracket
        r'(?!\()'       # not followed by opening paren (that would be a link)
    )
    self.default_rules.insert(0, 'change_type')

    self.rules.issue_link = re.compile(
        r'\('           # opening paren
        r'(#\d+)'       # hash and issue number
        r'\)'           # closing paren
    )
    self.default_rules.insert(0, 'issue_link')

    # Adjust the text rule to stop at open parentheses so that the issue_link
    # rule can trigger. Without this, issue_link would only match if it were the
    # first thing on the line.
    self.rules.text = re.compile(
        r'^[\s\S]+?(?=[\(\\<!\[_*`~]|https?://| {2,}\n|$)'
    )

  def output_change_type(self, m):
    """Translates change types like [fixed] into {{fixed}}."""
    tag = m.group(1)
    return self.renderer.change_type(tag)

  def output_issue_link(self, m):
    return (self.renderer.text('(') +
            self.renderer.autolink(m.group(1), False) +
            self.renderer.text(')'))


class Renderer(mistune.Renderer):

  def __init__(self, local_repo):
    super(Renderer, self).__init__()
    self.local_repo = local_repo

  def header(self, text, level, raw=None):
    return '%s %s\n' % ('#' * level, text)

  def list(self, body, ordered=True):
    if 'nested list' in body:
      pp(body)
    return '%s\n' % body

  def list_item(self, text):
    wrapper = textwrap.TextWrapper(
        initial_indent='* ', subsequent_indent='  ', width=79,
        break_long_words=False, break_on_hyphens=False)
    text = wrapper.fill(text)

    return '%s\n' % text

  def paragraph(self, text):
    return '%s\n\n' % text

  def double_emphasis(self, text):
    return '__%s__' % text

  def emphasis(self, text):
    return '_%s_' % text

  def codespan(self, text):
    return '`%s`' % text

  def linebreak(self):
    raise NotImplementedError('linebreak')

  def text(self, text):
    return text

  def escape(self, text):
    raise NotImplementedError('escape %s' % text)

  def autolink(self, link, is_email=False):
    return self.link(link, None, link)

  def link(self, link, title, text):
    link, text = self._adjust_link(link, text)
    if title is not None:
      link = '%s "%s"' % (link, title)
    return '[%s](%s)' % (text, link)

  def _adjust_link(self, link, text):
    m = re.match(r'^(?:https:)?(//github.com/(.*)/issues/(\d+))$', link)
    if m:
      link = m.group(1)
      repo = m.group(2)
      issue = m.group(3)

      if repo == self.local_repo:
        text = '#' + issue
      else:
        text = repo + '#' + issue

      return link, text

    m = re.match(r'^#(\d+)$', link)
    if m:
      issue = m.group(1)
      link = '//github.com/%s/issues/%s' % (self.local_repo, issue)
      return link, text

    return link, text

  def newline(self):
    return '\n'

  def change_type(self, tag):
    """Renders a change type in double curly braces.

    Renders [fixed] as {{fixed}}.
    """
    return '{{%s}}' % tag


def process_changelog(md, filename):
  with open(filename, 'r') as fd:
    text = fd.read()
    result = md(text)
    print(result)


def read_lines(filename):
  with open(filename, 'r') as fd:
    return [line.rstrip() for line in fd.readlines()]


if __name__ == '__main__':
  main()