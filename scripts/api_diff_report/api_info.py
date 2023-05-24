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
import subprocess
import icore_module
from urllib.parse import unquote
from bs4 import BeautifulSoup

API_INFO_FILE_NAME = 'api_info.json'


def main():
  logging.getLogger().setLevel(logging.INFO)

  # Parse command-line arguments
  args = parse_cmdline_args()
  output_dir = os.path.expanduser(args.output_dir)
  if not os.path.exists(output_dir):
    os.makedirs(output_dir)

  # Detect changed modules based on changed files
  changed_api_files = get_api_files(args.file_list)
  if not changed_api_files:
    logging.info('No Changed API File Detected')
    exit(0)
  changed_modules = icore_module.detect_changed_modules(changed_api_files)
  if not changed_modules:
    logging.info('No Changed Module Detected')
    exit(0)

  # Generate API documentation and parse API declarations
  # for each changed module
  api_container = {}
  for _, module in changed_modules.items():
    api_doc_dir = os.path.join(output_dir, 'doc', module['name'])
    build_api_doc(module, api_doc_dir)

    if os.path.exists(api_doc_dir):
      module_api_container = parse_module(api_doc_dir)
      api_container[module['name']] = {
          'path': api_doc_dir,
          'api_types': module_api_container
      }
    else:  # api doc fail to build.
      api_container[module['name']] = {'path': '', 'api_types': {}}

  api_info_path = os.path.join(output_dir, API_INFO_FILE_NAME)
  logging.info(f'Writing API data to {api_info_path}')
  with open(api_info_path, 'w') as f:
    f.write(json.dumps(api_container, indent=2))


def get_api_files(file_list):
  """Filter out non api files."""
  return [
      f for f in file_list
      if f.endswith('.swift') or (f.endswith('.h') and 'Public' in f)
  ]


def build_api_doc(module, output_dir):
  """Use Jazzy to build API documentation for a specific module's source
    code."""
  if module['language'] == icore_module.SWIFT:
    logging.info('------------')
    cmd = f'jazzy --module {module["name"]}'\
        + ' --swift-build-tool xcodebuild'\
        + ' --build-tool-arguments'\
        + f' -scheme,{module["scheme"]}'\
        + ',-destination,generic/platform=iOS,build'\
        + f' --output {output_dir}'
    logging.info(cmd)
    result = subprocess.Popen(cmd,
                              universal_newlines=True,
                              shell=True,
                              stdout=subprocess.PIPE)
    logging.info(result.stdout.read())
  elif module['language'] == icore_module.OBJECTIVE_C:
    logging.info('------------')
    cmd = 'jazzy --objc'\
        + f' --framework-root {module["root_dir"]}'\
        + f' --umbrella-header {module["umbrella_header"]}'\
        + f' --output {output_dir}'
    logging.info(cmd)
    result = subprocess.Popen(cmd,
                              universal_newlines=True,
                              shell=True,
                              stdout=subprocess.PIPE)
    logging.info(result.stdout.read())


def parse_module(api_doc_path):
  """Parse "${module}/index.html" and extract necessary information
    e.g.
    {
      $(api_type_1): {
        "api_type_link": $(api_type_link),
        "apis": {
          $(api_name_1): {
            "api_link": $(api_link_1),
            "declaration": [$(swift_declaration), $(objc_declaration)],
            "sub_apis": {
              $(sub_api_name_1): {"declaration": [$(swift_declaration)]},
              $(sub_api_name_2): {"declaration": [$(objc_declaration)]},
              ...
            }
          },
          $(api_name_2): {
            ...
          },
        }
      },
      $(api_type_2): {
        ..
      },
    }
    """
  module_api_container = {}
  # Read the HTML content from the file
  index_link = f'{api_doc_path}/index.html'
  with open(index_link, 'r') as file:
    html_content = file.read()

  # Parse the HTML content
  soup = BeautifulSoup(html_content, 'html.parser')

  # Locate the element with class="nav-groups"
  nav_groups_element = soup.find('ul', class_='nav-groups')
  # Extract data and convert to JSON format
  for nav_group in nav_groups_element.find_all('li', class_='nav-group-name'):
    api_type = nav_group.find('a').text
    api_type_link = nav_group.find('a')['href']

    apis = {}
    for nav_group_task in nav_group.find_all('li', class_='nav-group-task'):
      api_name = nav_group_task.find('a').text
      api_link = nav_group_task.find('a')['href']
      apis[api_name] = {'api_link': api_link, 'declaration': [], 'sub_apis': {}}

    module_api_container[api_type] = {
        'api_type_link': api_type_link,
        'apis': apis
    }

  parse_api(api_doc_path, module_api_container)

  return module_api_container


def parse_api(doc_path, module_api_container):
  """Parse API html and extract necessary information.

    e.g. ${module}/Classes.html
    """
  for api_type, api_type_abstract in module_api_container.items():
    api_type_link = f'{doc_path}/{unquote(api_type_abstract["api_type_link"])}'
    api_data_container = module_api_container[api_type]['apis']
    with open(api_type_link, 'r') as file:
      html_content = file.read()

    # Parse the HTML content
    soup = BeautifulSoup(html_content, 'html.parser')
    for api in soup.find('div', class_='task-group').find_all('li',
                                                              class_='item'):
      api_name = api.find('a', class_='token').text
      for api_declaration in api.find_all('div', class_='language'):
        api_declaration_text = ' '.join(api_declaration.stripped_strings)
        api_data_container[api_name]['declaration'].append(api_declaration_text)

    for api, api_abstruct in api_type_abstract['apis'].items():
      if api_abstruct['api_link'].endswith('.html'):
        parse_sub_api(f'{doc_path}/{unquote(api_abstruct["api_link"])}',
                      api_data_container[api]['sub_apis'])


def parse_sub_api(api_link, sub_api_data_container):
  """Parse SUB_API html and extract necessary information.

    e.g. ${module}/Classes/${class_name}.html
    """
  with open(api_link, 'r') as file:
    html_content = file.read()

  # Parse the HTML content
  soup = BeautifulSoup(html_content, 'html.parser')
  for s_api_group in soup.find_all('div', class_='task-group'):
    for s_api in s_api_group.find_all('li', class_='item'):
      api_name = s_api.find('a', class_='token').text
      sub_api_data_container[api_name] = {'declaration': []}
      for api_declaration in s_api.find_all('div', class_='language'):
        api_declaration_text = ' '.join(api_declaration.stripped_strings)
        sub_api_data_container[api_name]['declaration'].append(
            api_declaration_text)


def parse_cmdline_args():
  parser = argparse.ArgumentParser()
  parser.add_argument('-f', '--file_list', nargs='+', default=[])
  parser.add_argument('-o', '--output_dir', default='output_dir')

  args = parser.parse_args()
  return args


if __name__ == '__main__':
  main()
