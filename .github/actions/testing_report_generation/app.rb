# frozen_string_literal: true

# Copyright 2020 Google LLC
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
require 'json'
require 'tzinfo'

REPO_NAME_WITH_OWNER = ENV['GITHUB_REPOSITORY']
GITHUB_WORKFLOW_URL = "https://github.com/#{REPO_NAME_WITH_OWNER}/actions/runs/#{ENV['GITHUB_RUN_ID']}"
TESTS_TIME_INTERVAL_IN_HOURS = 24
TESTS_TIME_INTERVAL_IN_SECS = TESTS_TIME_INTERVAL_IN_HOURS * 3600
NO_WORKFLOW_RUNNING_INFO = "All nightly cron job were not run in the last #{TESTS_TIME_INTERVAL_IN_HOURS} hrs. Please review [log](#{GITHUB_WORKFLOW_URL}) make sure there at least exists one cron job running.".freeze
EXCLUDED_WORKFLOWS = []
ISSUE_LABELS = ""
ISSUE_TITLE = "Auto-Generated Testing Report"

if not ENV['INPUT_EXCLUDE-WORKFLOW-FILES'].nil?
  EXCLUDED_WORKFLOWS = ENV['INPUT_EXCLUDE-WORKFLOW-FILES'].split(/[ ,]/)
end
if not ENV['INPUT_ISSUE-LABELS'].nil?
  ISSUE_LABELS = ENV['INPUT_ISSUE-LABELS']
end
if not ENV['INPUT_ISSUE-TITLE'].nil?
  ISSUE_TITLE = ENV['INPUT_ISSUE-TITLE']
end
ASSIGNEE = ENV['INPUT_ASSIGNEES']
TIMEZONE = 'US/Pacific'

class Table
  def initialize(title)
    # tz is to help adjust daylight saving time and regular time.
    tz = TZInfo::Timezone.get(TIMEZONE)
    # tz.to_local(Time.new(2018, 3, 11, 2, 30, 0, "-08:00")) will return
    # 2018-03-11 03:30:00 -0700
    cur_time = tz.to_local(Time.now.utc.localtime("-08:00"))
    @is_empty_table = true
    @text = String.new ""
    @text << "# %s\n" % [title]
    @text << "This issue([log](%s)) is generated at %s, fetching workflow runs triggered in the last %s hrs.\n" % [GITHUB_WORKFLOW_URL, cur_time.strftime('%m/%d/%Y %H:%M %p'), TESTS_TIME_INTERVAL_IN_HOURS ]
    # get a table with two columns, workflow and the date of yesterday.
    @text << "| Workflow |"
    @text << (cur_time - TESTS_TIME_INTERVAL_IN_SECS).strftime('%m/%d') + "|"
    @text << "\n| -------- |"
    @text << " -------- |"
    @text << "\n"
  end

  def add_workflow_run_and_result(workflow, result)
    @is_empty_table = false if @is_empty_table
    record = "| %s | %s |\n" % [workflow, result]
    @text << record
  end

  def get_report()
    if @is_empty_table
      return nil
    end
    return @text
  end
end

def get_workflows(client, repo_name)
  workflow_page = 0
  workflows = []
  loop do
    workflow_page += 1
    cur_page_workflows = client.workflows(repo_name, :page => workflow_page).workflows
    if cur_page_workflows.length == 0
      break
    end
    workflows.push(*cur_page_workflows)
  end
  return workflows
end

failure_report = Table.new(ISSUE_TITLE)
success_report = Table.new(ISSUE_TITLE)
client = Octokit::Client.new(access_token: ENV["INPUT_ACCESS-TOKEN"])
last_issue = client.list_issues(REPO_NAME_WITH_OWNER, :labels => ISSUE_LABELS, :state => "all")[0]

puts "Excluded workflow files: " + EXCLUDED_WORKFLOWS.join(",")
for wf in get_workflows(client, REPO_NAME_WITH_OWNER) do
  # skip if it is the issue generation workflow.
  if wf.name == ENV["GITHUB_WORKFLOW"]
    next
  end
  workflow_file = File.basename(wf.path)
  puts "------------"
  puts "workflow_file: %s" % [workflow_file]
  if EXCLUDED_WORKFLOWS.include?(workflow_file)
    puts workflow_file + " is excluded in the report."
    next
  end

  workflow_text = "[%s](%s)" % [wf.name, wf.html_url]
  runs = client.workflow_runs(REPO_NAME_WITH_OWNER, File.basename(wf.path), :event => "schedule").workflow_runs
  runs = runs.sort_by { |run| -run.created_at.to_i }
  latest_run = runs[0]
  if latest_run.nil?
    puts "no schedule runs found."
  # Involved workflow runs triggered within one day.
  elsif Time.now.utc - latest_run.created_at < TESTS_TIME_INTERVAL_IN_SECS
    puts "created_at: %s" % [latest_run.created_at]
    puts "conclusion: %s" % [latest_run.conclusion]
    result_text = "[%s](%s)" % [latest_run.conclusion.nil? ? "in_process" : latest_run.conclusion, latest_run.html_url]
    if latest_run.conclusion == "success"
      success_report.add_workflow_run_and_result(workflow_text, result_text)
    else
      failure_report.add_workflow_run_and_result(workflow_text, result_text)
    end
  else
    puts "created_at: %s" % [latest_run.created_at]
    puts "conclusion: %s" % [latest_run.conclusion]
  end
end

# Check if there exists any cron jobs.
if failure_report.get_report.nil? && success_report.get_report.nil?
  if last_issue.state == "open"
    client.add_comment(REPO_NAME_WITH_OWNER, last_issue.number, NO_WORKFLOW_RUNNING_INFO)
  else
    client.create_issue(REPO_NAME_WITH_OWNER, ISSUE_TITLE, NO_WORKFLOW_RUNNING_INFO, labels: ISSUE_LABELS, assignee: ASSIGNEE)
  end
# Close an issue if all workflows succeed.
elsif failure_report.get_report.nil? and last_issue.state == "open"
  client.add_comment(REPO_NAME_WITH_OWNER, last_issue.number, success_report.get_report)
  client.close_issue(REPO_NAME_WITH_OWNER, last_issue.number)
# If the last issue is open, then failed report will be commented to the issue.
elsif !last_issue.nil? and last_issue.state == "open"
  client.add_comment(REPO_NAME_WITH_OWNER, last_issue.number,failure_report.get_report)
# Create a new issue if there exists failed workflows.
else
  client.create_issue(REPO_NAME_WITH_OWNER, ISSUE_TITLE, failure_report.get_report, labels: ISSUE_LABELS, assignee: ASSIGNEE) unless failure_report.get_report.nil?
end
