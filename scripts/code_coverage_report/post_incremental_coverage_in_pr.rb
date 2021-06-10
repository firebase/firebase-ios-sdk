# Copyright 2021 Google LLC
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

# USAGE: git diff -U0 [base_commit] HEAD | get_diff_lines.sh
#
# This will generate a JSON output of changed files and their newly added
# lines.

require 'octokit'
require 'json'

COMMENT_HEADER = "### Incremental code coverage report"
REMOVE_PATTERN = /### Incremental code coverage report/
REPO = ENV['GITHUB_REPOSITORY']
GITHUB_WORKFLOW_URL = "https://github.com/#{REPO}/actions/runs/#{ENV['GITHUB_RUN_ID']}"
UNCOVERED_LINE_FILE = ENV["UNCOVERED_LINE_FILE"]
TESTING_COMMIT = ENV["TESTING_COMMIT"]
PULL_REQUEST = ENV["PULL_REQUEST"].to_i

client = Octokit::Client.new(access_token: ENV["INPUT_ACCESS_TOKEN"])
uncovered_files = JSON.parse(File.read(UNCOVERED_LINE_FILE))

# Clean comments matching REMOVE_PATTERN.
def clean_coverage_comments(client)
  comment_page = 0
  loop do
    comment_page += 1
    cur_page_comment = client.pull_request_comments(REPO, PULL_REQUEST, { :per_page =>100, :page => comment_page })
    if cur_page_comment.length == 0
      break
    end
    for cmt in cur_page_comment do
      # Remove comments when the comment body meets the REMOVE_PATTERN.
      if cmt.body =~ REMOVE_PATTERN
        client.delete_pull_request_comment(REPO,cmt.id)
      end
    end
  end
end

def generate_comment(comment_header, xcresult_file)
  body = "Tests for New code lines are not detected in [#{xcresult_file}](#{GITHUB_WORKFLOW_URL}), please add tests on highlighted lines."
  return "#{comment_header} \n #{body}"
end

def add_coverage_comments(client, uncovered_files)
  for changed_file in uncovered_files do
    coverage_line = changed_file['coverage']
    xcresult_file = changed_file['xcresultBundle'].split('/').last
    start_line = -1
    coverage_line.each_with_index do |line, idx|
      # Init start_line to the first uncovered line of a file.
      if start_line == -1
        start_line = line
      end
      if idx < coverage_line.length() && line + 1 == coverage_line[idx+1]
        next
      else
        comment = generate_comment(COMMENT_HEADER, xcresult_file)
        if start_line == line
          # One line code comment will have nil in start_line and override
          # the position param, which is 0 here. The position param is a
          # relative number in the `git diff`, instead of a absolute line
          # index.
          client.create_pull_request_comment(REPO,PULL_REQUEST, comment, TESTING_COMMIT,changed_file['fileName'], 0, {:side=>"RIGHT", :line=>line})
        else
          # multiple-line code block comment needs start_line and line options,
          # which will override the position param.
          client.create_pull_request_comment(REPO,PULL_REQUEST, comment, TESTING_COMMIT,changed_file['fileName'],0, {:side=>"RIGHT", :start_line=>start_line, :line=>line})
        end
        start_line = coverage_line[idx+1]
      end
    end
  end
end

clean_coverage_comments(client)
add_coverage_comments(client, uncovered_files)
