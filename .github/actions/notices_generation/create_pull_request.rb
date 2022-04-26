# frozen_string_literal: true

# Copyright 2022 Google LLC
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

require 'octokit'
require 'optparse'

@options = {
  repo_root: "./"
}
begin
  OptionParser.new do |opts|
    opts.banner = "Usage: create_pull_request.rb [options]"
    opts.on('-r', '--repo-root', 'Root path of the repo dir.') { |v| @options[:repo_root] = v }
    opts.on('-t', '--repo-token', 'Token with write access') { |v| @options[:repo_token] = v }
    opts.on('-n', '--notices-path', 'Path of NOTICES file') { |v| @options[:notices_path] = v }
  end.parse!

  raise OptionParser::MissingArgument if @options[:repo_token].nil? || @options[:notices_path].nil?
rescue OptionParser::MissingArgument
  puts "Notices path, `--notices-path`, should be specified. " if @options[:notices_path].nil?
  puts "A token ,`--repo-token`, should be provided for creating a pull request." if @options[:repo_token].nil?
  raise
end

REPO_ROOT=@options[:repo_root]
ACCESS_TOKEN=@options[:repo_token]
NOTICES_PATH=@options[:notices_path]

def generate_pr_for_notices_changes(repo_root:, notices_path:)
  puts @options
  `cd #{repo_root}`
  `git clone -q https://"${ACCESS_TOKEN}"@github.com/firebase/firebase-ios-sdk.git "temp"`
  `cp #{NOTICES_PATH} temp/CoreOnly/NOTICES`
  `cd temp`
  `git checkout -b notices_diff_detected`
  `git add temp/CoreOnly/NOTICES`
  `git commit -m "NOTICES diff detected."`
  `git push -u origin notices_diff_detected`
  client = Octokit::Client.new(access_token: ACCESS_TOKEN)
  client.create_pull_request("firebase/firebase-ios-sdk", "main", "notices_diff_detected", "Pull Request title", "Pull Request body")
end


def main()
  generate_pr_for_notices_changes(repo_root: REPO_ROOT, notices_path: NOTICES_PATH)
end

main()
