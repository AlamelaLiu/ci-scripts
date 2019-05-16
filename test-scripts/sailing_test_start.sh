#!/bin/bash -x
# -*- coding: utf-8 -*-

#: Title                  : jenkins_boot_start.sh
#: Usage                  : ./local/ci-scripts/test-scripts/jenkins_boot_start.sh -p env.properties
#: Author                 : qinsl0106@thundersoft.com
#: Description            : CI中 测试部分 的jenkins任务脚本

__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD

function main()
{
   echo $1 $2
}

main "$@"
