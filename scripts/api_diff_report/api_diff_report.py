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

STATUS_ADD = 'ADDED'
STATUS_REMOVED = 'REMOVED'
STATUS_MODIFIED = 'MODIFIED'
STATUS_ERROR = 'BUILD ERROR'
API_DIFF_FILE_NAME = 'api_diff_report.markdown'


def main():
  logging.getLogger().setLevel(logging.INFO)

  args = parse_cmdline_args()

  new_api_file = os.path.join(os.path.expanduser(args.pr_branch),
                              api_info.API_INFO_FILE_NAME)
  old_api_file = os.path.join(os.path.expanduser(args.base_branch),
                              api_info.API_INFO_FILE_NAME)
  if os.path.exists(new_api_file):
    with open(new_api_file) as f:
      new_api_json = json.load(f)
  else:
    new_api_json = {}
  if os.path.exists(old_api_file):
    with open(old_api_file) as f:
      old_api_json = json.load(f)
  else:
    old_api_json = {}

  diff = generate_diff_json(new_api_json, old_api_json)
  if diff:
    logging.info(f'json diff: \n{json.dumps(diff, indent=2)}')
    logging.info(f'plain text diff report: \n{generate_text_report(diff)}')
    report = generate_markdown_report(diff)
    logging.info(f'markdown diff report: \n{report}')
  else:
    logging.info('No API Diff Detected.')
    report = ""

  output_dir = os.path.expanduser(args.output_dir)
  if not os.path.exists(output_dir):
    os.makedirs(output_dir)
  api_report_path = os.path.join(output_dir, API_DIFF_FILE_NAME)
  logging.info(f'Writing API diff report to {api_report_path}')
  with open(api_report_path, 'w') as f:
    f.write(report)


def generate_diff_json(new_api, old_api, level='module'):
  """diff_json only contains module & api that has a change.

    format:
    {
      $(module_name_1): {
        "api_types": {
          $(api_type_1): {
            "apis": {
              $(api_1): {
                "declaration": [
                  $(api_1_declaration)
                ],
                "sub_apis": {
                  $(sub_api_1): {
                    "declaration": [
                      $(sub_api_1_declaration)
                    ]
                  },
                },
                "status": $(diff_status)
              }
            }
          }
        }
      }
    }
    """
  NEXT_LEVEL = {'module': 'api_types', 'api_types': 'apis', 'apis': 'sub_apis'}
  next_level = NEXT_LEVEL.get(level)

  diff = {}
  for key in set(new_api.keys()).union(old_api.keys()):
    # Added API
    if key not in old_api:
      diff[key] = new_api[key]
      diff[key]['status'] = STATUS_ADD
      if diff[key].get('declaration'):
        diff[key]['declaration'] = [STATUS_ADD] + diff[key]['declaration']
    # Removed API
    elif key not in new_api:
      diff[key] = old_api[key]
      diff[key]['status'] = STATUS_REMOVED
      if diff[key].get('declaration'):
        diff[key]['declaration'] = [STATUS_REMOVED] + diff[key]['declaration']
    # Module Build Error. If a "module" exist but have no
    # content (e.g. doc_path), it must have a build error.
    elif level == 'module' and (not new_api[key]['path']
                                or not old_api[key]['path']):
      diff[key] = {'status': STATUS_ERROR}
    # Check diff in child level and diff in declaration
    else:
      child_diff = generate_diff_json(new_api[key][next_level],
                                      old_api[key][next_level],
                                      level=next_level) if next_level else {}
      declaration_diff = new_api[key].get('declaration') != old_api[key].get(
          'declaration') if level in ['apis', 'sub_apis'] else False

      # No diff
      if not child_diff and not declaration_diff:
        continue

      diff[key] = new_api[key]
      # Changes at child level
      if child_diff:
        diff[key][next_level] = child_diff

      # Modified API (changes in API declaration)
      if declaration_diff:
        diff[key]['status'] = STATUS_MODIFIED
        diff[key]['declaration'] = [STATUS_ADD] + \
            new_api[key]['declaration'] + \
            [STATUS_REMOVED] + \
            old_api[key]['declaration']

  return diff


def generate_text_report(diff, level=0, print_key=True):
  report = ''
  indent_str = '  ' * level
  for key, value in diff.items():
    # filter out  ["path", "api_type_link", "api_link", "declaration", "status"]
    if isinstance(value, dict):
      if key in ['api_types', 'apis', 'sub_apis']:
        report += generate_text_report(value, level=level)
      else:
        status_text = f"{value.get('status', '')}:" if 'status' in value else ''
        if status_text:
          if print_key:
            report += f'{indent_str}{status_text} {key}\n'
          else:
            report += f'{indent_str}{status_text}\n'
        if value.get('declaration'):
          for d in value.get('declaration'):
            report += f'{indent_str}{d}\n'
        else:
          report += f'{indent_str}{key}\n'
        report += generate_text_report(value, level=level + 1)

  return report


def generate_markdown_report(diff, level=0):
  report = ''
  header_str = '#' * (level + 3)
  for key, value in diff.items():
    if isinstance(value, dict):
      if key in ['api_types', 'apis', 'sub_apis']:
        report += generate_markdown_report(value, level=level)
      else:
        current_status = value.get('status')
        if current_status:
          # Module level: Always print out module name and class name as title
          if level in [0, 2]:
            report += f'{header_str} [{current_status}] {key}\n'
          if current_status != STATUS_ERROR:  # ADDED,REMOVED,MODIFIED
            report += '<details>\n<summary>\n'
            report += f'[{current_status}] {key}\n'
            report += '</summary>\n\n'
            declarations = value.get('declaration', [])
            sub_report = generate_text_report(value, level=1, print_key=False)
            detail = process_declarations(current_status, declarations,
                                          sub_report)
            report += f'```diff\n{detail}\n```\n\n</details>\n\n'
        else:  # no diff at current level
          report += f'{header_str} {key}\n'
          report += generate_markdown_report(value, level=level + 1)
        # Module level: Always print out divider in the end
        if level == 0:
          report += '-----\n'

  return report


def process_declarations(current_status, declarations, sub_report):
  """Diff syntax highlighting in Github Markdown."""
  detail = ''
  if current_status == STATUS_MODIFIED:
    for line in (declarations + sub_report.split('\n')):
      if STATUS_ADD in line:
        prefix = '+ '
        continue
      elif STATUS_REMOVED in line:
        prefix = '- '
        continue
      if line:
        detail += f'{prefix}{line}\n'
  else:
    prefix = '+ ' if current_status == STATUS_ADD else '- '
    for line in (declarations + sub_report.split('\n')):
      if line:
        detail += f'{prefix}{line}\n'

  return categorize_declarations(detail)


def categorize_declarations(detail):
  """Categorize API info by Swift and Objective-C."""
  lines = detail.split('\n')

  swift_lines = [line.replace('Swift', '') for line in lines if 'Swift' in line]
  objc_lines = [
      line.replace('Objective-C', '') for line in lines if 'Objective-C' in line
  ]

  swift_detail = 'Swift:\n' + '\n'.join(swift_lines) if swift_lines else ''
  objc_detail = 'Objective-C:\n' + '\n'.join(objc_lines) if objc_lines else ''

  if not swift_detail and not objc_detail:
    return detail
  else:
    return f'{swift_detail}\n{objc_detail}'.strip()


def parse_cmdline_args():
  parser = argparse.ArgumentParser()
  parser.add_argument('-p', '--pr_branch')
  parser.add_argument('-b', '--base_branch')
  parser.add_argument('-o', '--output_dir', default='output_dir')

  args = parser.parse_args()
  return args


if __name__ == '__main__':
  main()
