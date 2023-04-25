# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
import argparse
import logging
import os
import api_info
import datetime
import pytz

STATUS_ADD = "ADDED"
STATUS_REMOVED = "REMOVED"
STATUS_MODIFIED = "MODIFIED"
STATUS_ERROR = "BUILD ERROR"

def main():
  logging.getLogger().setLevel(logging.INFO)

  args = parse_cmdline_args()

  merged_branch = os.path.expanduser(args.merged_branch)
  base_branch = os.path.expanduser(args.base_branch)
  new_api_json = json.load(open(os.path.join(merged_branch, api_info.API_INFO_FILE_NAME)))
  old_api_json = json.load(open(os.path.join(base_branch, api_info.API_INFO_FILE_NAME)))

  diff = generate_diff_json(new_api_json, old_api_json)
  if diff:
    logging.info(f"json diff: \n{json.dumps(diff, indent=2)}")
    logging.info(f"plain text diff report: \n{generate_text_report(diff)}")
    logging.info(f"markdown diff report title: \n{generate_markdown_title(args.commit, args.run_id)}")
    logging.info(f"markdown diff report: \n{generate_markdown_report(diff)}")
  else:
    logging.info("No API Diff Detected.")


# diff_json only contains module & api that has a change. format:
# {
#   $(moduel_name_1): {
#     "api_types": {
#       $(api_type_1): {
#         "apis": {
#           $(api_1): {
#             "declaration": [
#               $(api_1_declaration)
#             ],
#             "sub_apis": {
#               $(sub_api_1): {
#                 "declaration": [
#                   $(sub_api_1_declaration)
#                 ]
#               },
#             },
#             "status": $(diff_status)
#           }
#         }
#       }
#     }
#   }
# }
def generate_diff_json(new_api, old_api, level="module"):
  NEXT_LEVEL = {"module": "api_types", "api_types": "apis", "apis": "sub_apis"}
  next_level = NEXT_LEVEL.get(level)

  diff = {}
  for key in set(new_api.keys()).union(old_api.keys()):
    # Added API
    if key not in old_api:
      diff[key] = new_api[key]
      diff[key]["status"] = STATUS_ADD
      if diff[key].get("declaration"):
        diff[key]["declaration"] = [STATUS_ADD] + diff[key]["declaration"]
    # Removed API
    elif key not in new_api:
      diff[key] = old_api[key]
      diff[key]["status"] = STATUS_REMOVED
      if diff[key].get("declaration"):
        diff[key]["declaration"] = [STATUS_ADD] + diff[key]["declaration"]
    # Moudle Build Error. If a "module" exist but have no content (e.g. doc_path), it must have a build error.
    elif level == "module" and (not new_api[key]["path"] or not old_api[key]["path"]):
      diff[key] = {"status": STATUS_ERROR}
    else:
      child_diff = generate_diff_json(new_api[key][next_level], old_api[key][next_level], level=next_level) if next_level else {}
      declaration_diff = new_api[key].get("declaration") != old_api[key].get("declaration") if level in ["apis", "sub_apis"] else False

      # No changes at current level
      if not child_diff and not declaration_diff: # no diff
        continue

      diff[key] = new_api[key]
      # Changes at child level
      if child_diff:
        diff[key][next_level] = child_diff

      # Modified API (changes in API declaration)
      if declaration_diff:
        diff[key]["status"] = STATUS_MODIFIED
        diff[key]["declaration"] = [STATUS_ADD] + new_api[key]["declaration"] + [STATUS_REMOVED] + old_api[key]["declaration"]

  return diff


def generate_text_report(diff, level=0, print_key=True):
  report = ''
  indent_str = '  ' * level
  for key, value in diff.items():
    if isinstance(value, dict): # filter out  ["path", "api_type_link", "api_link", "declaration", "status"]
      if key in ["api_types", "apis", "sub_apis"]:
        report += generate_text_report(value, level=level)
      else:
        status_text = f"{value.get('status', '')}: " if 'status' in value else ''
        if status_text:
          if print_key:
            report += f"{indent_str}{status_text}{key}\n"
          else:
            report += f"{indent_str}{status_text}\n"
        if value.get('declaration'):
          for d in value.get('declaration'):
            report += f"{indent_str}{d}\n"
        else:
          report += f"{indent_str}{key}\n"
        report += generate_text_report(value, level=level + 1)

  return report


def generate_markdown_title(commit, run_id):
  pst_now = datetime.datetime.utcnow().astimezone(pytz.timezone("America/Los_Angeles"))
  return ("## Apple API Diff Report\n" +
          "Commit: %s\n" % commit +
          "Last updated: %s \n" % pst_now.strftime("%a %b %e %H:%M %Z %G") +
          "**[View workflow logs & download artifacts](https://github.com/firebase/firebase-cpp-sdk/actions/runs/%s)**\n\n" % run_id +
          "-----\n")


def generate_markdown_report(diff, level=0):
  report = ''
  header_str = '#' * (level+3)
  for key, value in diff.items():
    if isinstance(value, dict):
      if key in ["api_types", "apis", "sub_apis"]:
        report += generate_markdown_report(value, level=level)
      else:
        current_status = value.get('status')
        if current_status:
          if level==0: # Module level: Always print out module name as title
            report +=  f"{header_str} {key} [{current_status}]\n"
          if current_status != STATUS_ERROR: # ADDED,REMOVED,MODIFIED
            report += f"<details>\n<summary>\n[{current_status}] {key}\n</summary>\n\n"
            declarations = value.get('declaration', [])
            sub_report = generate_text_report(value, level=1, print_key=False)
            detail = process_declarations(current_status, declarations, sub_report)
            report += f"```diff\n{detail}\n```\n\n</details>\n\n"
        else: # no diff at current level
          report += f"{header_str} {key}\n"
          report += generate_markdown_report(value, level=level+1)

        if level==0: # Module level: Always print out divider at the end
          report +=  "-----\n"

  return report


# Diff syntax highlighting in Github Markdown
def process_declarations(current_status, declarations, sub_report):
  detail = ""
  if current_status == STATUS_MODIFIED:
    for line in (declarations + sub_report.split("\n")):
      if STATUS_ADD in line:
        prefix = "+ "
        continue
      elif STATUS_REMOVED in line:
        prefix = "- "
        continue
      if line:
        detail += f"{prefix}{line}\n"
  else:
    prefix = "+ " if current_status == STATUS_ADD else "- "
    for line in (declarations + sub_report.split("\n")):
      if line:
        detail += f"{prefix}{line}\n"

  return categorize_declarations(detail)


# Categorize API info by Swift and Objective-C
def categorize_declarations(detail):
  lines = detail.split("\n")

  swift_lines = [line.replace("Swift", "") for line in lines if "Swift" in line]
  objc_lines = [line.replace("Objective-C", "") for line in lines if "Objective-C" in line]

  swift_detail = "Swift:\n" + "\n".join(swift_lines) if swift_lines else ""
  objc_detail = "Objective-C:\n" + "\n".join(objc_lines) if objc_lines else ""

  if not swift_detail and not objc_detail:
    return detail
  else:
    return f'{swift_detail}\n{objc_detail}'.strip()


def parse_cmdline_args():
  parser = argparse.ArgumentParser()
  parser.add_argument('-m', '--merged_branch')
  parser.add_argument('-b', '--base_branch')
  parser.add_argument('-c', '--commit')
  parser.add_argument('-i', '--run_id')

  args = parser.parse_args()
  return args


if __name__ == '__main__':
  main()
