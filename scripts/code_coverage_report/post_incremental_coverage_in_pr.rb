require 'octokit'
require 'json'

COMMENT = "### Incremental code coverage report \nNew code lines here are not covered by tests, please add tests on highlighted lines."
REMOVE_PATTERN = /### Incremental code coverage report/
REPO = ENV['GITHUB_REPOSITORY']
UNCOVERED_LINE_FILE = ENV["UNCOVERED_LINE_FILE"]
TESTING_COMMIT = ENV["TESTING_COMMIT"]
PULL_REQUEST = ENV["PULL_REQUEST"].to_i

client = Octokit::Client.new(access_token: ENV["INPUT_ACCESS_TOKEN"])
uncovered_files = JSON.parse(File.read(UNCOVERED_LINE_FILE))


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

def add_coverage_comments(client, uncovered_files)
  for changed_file in uncovered_files do
    coverage_line = changed_file['coverage']
    start_line = -1
    coverage_line.each_with_index do |line, idx|
      # Init start_line to the first uncovered line of a file.
      if start_line == -1 
        start_line = line
      end
      if idx < coverage_line.length() && line + 1 == coverage_line[idx+1]
        next
      else
        if start_line == line
          # One line code comment will only rely on the position param, which is
          # 'line' here.
          client.create_pull_request_comment(REPO,PULL_REQUEST, COMMENT,TESTING_COMMIT,changed_file['file'], line, {:side=>"RIGHT"})
        else
          # multiple-line code block comment needs start_line and line options,
          # which will override the position param.
          client.create_pull_request_comment(REPO,PULL_REQUEST, COMMENT,TESTING_COMMIT,changed_file['file'],0, {:side=>"RIGHT", :start_line=> start_line, :line=> line})
        end
        start_line = coverage_line[idx+1]
      end
    end
  end
end

clean_coverage_comments(client)
add_coverage_comments(client, uncovered_files)
