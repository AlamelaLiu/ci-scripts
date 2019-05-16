#!/bin/bash -x
# -*- coding: utf-8 -*-

#: Title                  : jenkins_boot_start.sh
#: Usage                  : ./local/ci-scripts/test-scripts/jenkins_boot_start.sh -p env.properties
#: Author                 : qinsl0106@thundersoft.com
#: Description            : CI中 测试部分 的jenkins任务脚本

__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD

function download_repo()
{
   
   pushd /fileserver
   DIR_NAME=`echo ${TEST_REPO} | cut -d '/' -f 5 | cut -d '.' -f 1`
   TEST_CASE_DIR=/fileserver/${DIR_NAME}
   ls | grep ${DIR_NAME}
   if [ $? -eq '0' ];then
      pushd ${DIR_NAME}
      git pull 
      popd
   else
      git clone $TEST_REPO
   fi
   popd
}

function main()
{
   DUT_IP=$1
   TEST_REPO=$2
   SCOPE=$3
  
   set_device 
   download_repo
   python sailing-ci-job-creator.py  --testUrl "${TEST_REPO}" --testDir "${TEST_CASE_DIR}" --scope "${TEST_SCOPE}"
   pwd 
}

main "$@"
