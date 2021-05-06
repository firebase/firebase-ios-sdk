require 'octokit'
require 'optparse'
require 'json'

COMMENT = "### Incremental code coverage report \nNew code lines here are not covered by tests, please add tests on highlighted lines."
REMOVE_PATTERN = /### Incremental code coverage report/
PULL_REQUEST = ENV["PULL_REQUEST"].to_i

client = Octokit::Client.new(access_token: ENV["INPUT_ACCESS_TOKEN"])
uncovered_files = JSON.parse(File.read(UNCOVERED_LINE_FILE))
for cmt in client.pull_request_comments(REPO, PULL_REQUEST, { :per_page =>100 }) do
  if cmt.body =~ REMOVE_PATTERN 
    client.delete_pull_request_comment(REPO,cmt.id)
  end
end
for changed_file in uncovered_files do
  coverage_line = changed_file['coverage']
  start_line = -1
  coverage_line.each_with_index do |line, idx|
    puts "#{line} => #{idx}"
    if start_line == -1 
      start_line = line
    end
    if idx < coverage_line.length() && line + 1 == coverage_line[idx+1]
      next
    else
      puts "#{start_line} #{line}"
      if start_line == line
        client.create_pull_request_comment(REPO,PULL_REQUEST, COMMENT,TESTING_COMMIT,changed_file['file'], line, {:side=>"RIGHT"})
      else
        client.create_pull_request_comment(REPO,PULL_REQUEST, COMMENT,TESTING_COMMIT,changed_file['file'],0, {:side=>"RIGHT", :start_line=> start_line, :line=> line})
      end
      start_line = coverage_line[idx+1]
    end
  end
end
