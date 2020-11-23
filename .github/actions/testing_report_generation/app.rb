# frozen_string_literal: true

require 'octokit'
require 'optparse'
require "json"

REPO_NAME_WITH_OWNER = 'firebase/firebase-ios-sdk'.freeze
REPORT_TESTING_REPO = 'granluo/issue_generations'.freeze
excluded_workflows = []
issue_labels = []
if not ENV['INPUT_EXCLUDE-WORKFLOW-FILES'].nil?
  excluded_workflows = ENV['INPUT_EXCLUDE-WORKFLOW-FILES'].split(/[ ,]/)
end
if not ENV['INPUT_ISSUE_LABELS'].nil?
  issue_labels = ENV['INPUT_ISSUE_LABELS'].split(/[ ,]/)
end
assignee = ENV['INPUT_ASSIGNEES']

class Table
  def initialize(title)
    cur_time = Time.now.utc.localtime("-07:00")
    @text = String.new ""
    @text << "# %s\n" % [title]
    @text << "Failures are detected in workflow(s)\n"
    @text << "This issue is generated at %s\n" % [cur_time.strftime('%m/%d/%Y %H:%M %p') ]
    @text << "| Workflow |"
    @text << (cur_time - 86400).strftime('%m/%d') + "|"
    @text << "\n| -------- |"
    @text << " -------- |"
    @text << "\n"
  end 

  def add_workflow_run_and_result(workflow, result)
    record = "| %s | %s |\n" % [workflow, result]
    @text << record
  end 

  def get_report()
    return @text
  end 
end 

report = Table.new("Nightly Testing Report")
client = Octokit::Client.new(access_token: ENV["INPUT_ACCESS-TOKEN"])
last_issue = client.list_issues(REPORT_TESTING_REPO, :labels => ENV['INPUT_ISSUE-LABEL'])[0]
workflows = client.workflows(REPO_NAME_WITH_OWNER)

puts "Excluded workflow files: " + excluded_workflows.join(",")
for wf in workflows.workflows do
  workflow_file = File.basename(wf.path)
  puts workflow_file
  workflow_text = "[%s](%s)" % [wf.name, wf.html_url]
  runs = client.workflow_runs(REPO_NAME_WITH_OWNER, File.basename(wf.path), :event => "schedule").workflow_runs 
  runs = runs.sort_by { |run| -run.created_at.to_i }
  latest_run = runs[0]
  if latest_run.nil?
    puts "no schedule runs found."
  elsif excluded_workflows.include?(workflow_file)
    puts workflow_file + " is excluded in the report."
  elsif Time.now.utc - latest_run.created_at < 86400
    puts latest_run.event + latest_run.html_url + " " + latest_run.created_at.to_s + " " + latest_run.conclusion
    result_text = "[%s](%s)" % [latest_run.conclusion, latest_run.html_url]
    report.add_workflow_run_and_result(workflow_text, result_text) unless latest_run.conclusion == "success"
  end
end

if not last_issue.nil? && last_issue.state == "open"
  client.add_comment(REPORT_TESTING_REPO, last_issue.number,report.get_report)
else
  new_issue = client.create_issue(REPORT_TESTING_REPO, 'Nightly Testing Report' + Time.now.utc.localtime("-07:00").strftime('%m/%d/%Y %H:%M %p'), report.get_report, labels: issue_labels, assignee: assignee)
end
