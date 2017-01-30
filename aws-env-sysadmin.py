#!/usr/bin/env python
# -*- coding: UTF-8 -*-
# aws-env-sysadmin.py, ABr, 20161024

import sys
import json
import argparse
from subprocess import call

__version__ = '0.1'

class DoStack(object):
  def __init__(self, cmd, option, region, name, file_template, overrides):
    self.aws_cmd = cmd
    self.aws_option = option
    self.aws_region = region
    self.aws_name = name
    self.file_template = file_template
    self.overrides = overrides
    self.run()

  def run(self):
    # command command options
    cmd_opts = [
      # region info
      '--region', self.aws_region,
      # command info
      'cloudformation', '' + self.aws_option + '-stack',
      # specific options
      '--stack-name', self.aws_name,
      '--template-body', "file://" + self.file_template + "",
      '--capabilities', 'CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM'
    ]

    # additional options
    if self.aws_option == 'create':
      cmd_opts.append('--disable-rollback')

    # now parameters
    cmd_parms = [
      '--parameters',
      "ParameterKey=InstanceCount,ParameterValue=1"
    ]

    # overrides
    for key in self.overrides:
      cmd_parms.append('"ParameterKey={},ParameterValue={}"'.format(key, self.overrides[key]))

    # invoke the command
    cmd_array = [self.aws_cmd]
    cmd_array.extend(cmd_opts)
    cmd_array.extend(cmd_parms)
    print ' '.join(cmd_array)
    #call(cmd_array)

def main():
  parser = argparse.ArgumentParser()
  parser.add_argument('-V', '--version', action='version', version=__version__)
  parser.add_argument('--cmd', help='aws CLI name', default='aws')
  parser.add_argument('--option', help='create or update', required=True)
  parser.add_argument('--region', help='AWS region name', default='us-west-2')
  parser.add_argument('--name', help='Stack Name', default='aws-sysadmin-test-env-1')
  parser.add_argument('--file-template', help='Template File', required=True)
  parser.add_argument('--override-keys', help='Parameter Overrides - Keynames', nargs='*', required=False)
  parser.add_argument('--override-values', help='Parameter Overrides - Values', nargs='*', required=False)
  args = parser.parse_args()

  # handle overrides
  overrides = {}
  arg_override_keys = args.override_keys
  arg_override_values = args.override_values
  if (arg_override_keys and arg_override_values):
    if (type(arg_override_keys) in (tuple, list) and type(arg_override_values) in (tuple, list)):
      if (len(arg_override_keys) != len(arg_override_values)):
        raise ValueError('override-keys count must equal override-values count')
      for x in xrange(len(arg_override_keys)):
        overrides[arg_override_keys[x]] = arg_override_values[x]

  # invoke  
  DoStack(cmd = args.cmd, option = args.option, region = args.region, name = args.name, file_template = args.file_template, overrides = overrides)

if __name__ == '__main__':
  main()

