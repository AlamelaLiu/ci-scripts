#!/bin/bash -ex
# -*- coding: utf-8 -*-

#: Title                  : jenkins_boot_start.sh
#: Usage                  : ./local/ci-scripts/test-scripts/jenkins_boot_start.sh -p env.properties
#: Author                 : qinsl0106@thundersoft.com
#: Description            : CI中 测试部分 的jenkins任务脚本

__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
#script_path=$(cd "`dirname $0`";pwd)
source "${script_path}/../common-scripts/common.sh"

JOB_ID=0
JOB_RESULT_MAIL="Unknow"

function init_build_option() {
    SKIP_LAVA_RUN=${SKIP_LAVA_RUN:-"false"}
}

function init_workspace() {
    #WORKSPACE=${WORKSPACE:-/home/ts/jenkins/workspace/plinth-ci}
	WORKSPACE="/home/ts/jenkins/workspace/plinth-ci"
    #[ ! -d /home/ts/jenkins/workspace/plinth-ci ] && mkdir -p ${WORKSPACE}
}

function init_input_params() {

    TREE_NAME=${TREE_NAME:-"open-estuary"}

    VERSION=${VERSION:-""}

    GIT_DESCRIBE=${GIT_DESCRIBE:-""}

    DEBUG=${DEBUG:-""}

    JENKINS_JOB_INFO=$(expr "${BUILD_URL}" : '^http.*/job/\(.*\)/$' | sed "s#/#-#g")

    JENKINS_JOB_START_TIME=${JENKINS_JOB_START_TIME:-$(current_time)}
}

function parse_params() {
    pushd ${CI_SCRIPTS_DIR}
    : ${SHELL_PLATFORM:=`python configs/parameter_parser.py -f config_plinth.yaml -s Build -k Platform`}
    : ${SHELL_DISTRO:=`python configs/parameter_parser.py -f config_plinth.yaml -s Build -k Distro`}

    : ${BOOT_PLAN:=`python configs/parameter_parser.py -f config_plinth.yaml -s Jenkins -k Boot`}

    : ${TEST_PLAN:=`python configs/parameter_parser.py -f config_plinth.yaml -s Test -k Plan`}
    : ${TEST_SCOPE:=`python configs/parameter_parser.py -f config_plinth.yaml -s Test -k Scope`}
    : ${TEST_REPO:=`python configs/parameter_parser.py -f config_plinth.yaml -s Test -k Repo`}
    : ${TEST_LEVEL:=`python configs/parameter_parser.py -f config_plinth.yaml -s Test -k Level`}

    : ${LAVA_SERVER:=`python configs/parameter_parser.py -f config_plinth.yaml -s LAVA -k lavaserver`}
    : ${LAVA_USER:=`python configs/parameter_parser.py -f config_plinth.yaml -s LAVA -k lavauser`}
    : ${LAVA_STREAM:=`python configs/parameter_parser.py -f config_plinth.yaml -s LAVA -k lavastream`}
    : ${LAVA_TOKEN:=`python configs/parameter_parser.py -f config_plinth.yaml -s LAVA -k TOKEN`}

    : ${LAVA_DISPLAY_URL:=`python configs/parameter_parser.py -f config_plinth.yaml -s LAVA -k LAVA_DISPLAY_URL`}

    : ${FTP_SERVER:=`python configs/parameter_parser.py -f config_plinth.yaml -s Ftpinfo -k ftpserver`}
    : ${FTPSERVER_DISPLAY_URL:=`python configs/parameter_parser.py -f config_plinth.yaml -s Ftpinfo -k FTPSERVER_DISPLAY_URL`}
    : ${FTP_DIR:=`python configs/parameter_parser.py -f config_plinth.yaml -s Ftpinfo -k FTP_DIR`}

    : ${ARCH_MAP:=`python configs/parameter_parser.py -f config_plinth.yaml -s Arch`}

    : ${SUCCESS_MAIL_LIST:=`python configs/parameter_parser.py -f config_plinth.yaml -s Mail -k SUCCESS_LIST`}
    : ${SUCCESS_MAIL_CC_LIST:=`python configs/parameter_parser.py -f config_plinth.yaml -s Mail -k SUCCESS_CC_LIST`}
    : ${FAILED_MAIL_LIST:=`python configs/parameter_parser.py -f config_plinth.yaml -s Mail -k FAILED_LIST`}
    : ${FAILED_MAIL_CC_LIST:=`python configs/parameter_parser.py -f config_plinth.yaml -s Mail -k FAILED_CC_LIST`}

    popd    # restore current work directory
}

function save_properties_and_result() {
    local test_result=$1

    cat << EOF > ${WORKSPACE}/env.properties
TREE_NAME=${TREE_NAME}
GIT_DESCRIBE=${GIT_DESCRIBE}
SHELL_PLATFORM="${SHELL_PLATFORM}"
SHELL_DISTRO="${SHELL_DISTRO}"
BOOT_PLAN=${BOOT_PLAN}
TEST_REPO=${TEST_REPO}
TEST_SCOPE="${TEST_SCOPE}"
TEST_LEVEL=${TEST_LEVEL}
DEBUG=${DEBUG}
JENKINS_JOB_START_TIME="${JENKINS_JOB_START_TIME}"
ARCH_MAP="${ARCH_MAP}"
EOF
    # EXECUTE_STATUS="Failure"x
    cat ${WORKSPACE}/env.properties

    echo "${test_result}" > ${WORKSPACE}/test_result.txt
}

function prepare_tools() {
    dev_tools="python-yaml python-keyring expect"

    if ! (dpkg-query -l $dev_tools >/dev/null 2>&1); then
        sudo apt-get update
        if ! (sudo apt-get install -y --force-yes $dev_tools); then
            echo "ERROR: can't install tools: ${dev_tools}"
            exit 1
        fi
    fi
}

function init_boot_env() {
    JOBS_DIR=jobs
    RESULTS_DIR=results

    # 2. 今日构建结果
    WHOLE_SUM='whole_summary.txt'

    # 3. 测试数据统计
    SCOPE_SUMMARY_NAME='scope_summary.txt'

    # 6. 详细测试结果
    DETAILS_SUM='details_summary.txt'

    RESULT_JSON="test_result_dict.json"

    PDF_FILE='resultfile.pdf'
}

function generate_jobs() {
    local test_name=$1
	
	#ubuntu
    local distro=$2

    pwd
    for PLAT in $SHELL_PLATFORM; do
        board_arch=${dict[$PLAT]}
        if [ x"$distro" != x"" ]; then
            python plinth-ci-job-creator.py "$FTP_SERVER/${TREE_NAME}/${GIT_DESCRIBE}/${PLAT}-${board_arch}/" \
                   --tree "${TREE_NAME}" --plans "$test_name" --distro "$distro" --arch "${board_arch}" \
                   --testUrl "${TEST_REPO}" --testDir "${TEST_CASE_DIR}" --plan "${TEST_PLAN}" --scope "${TEST_SCOPE}" --level "${TEST_LEVEL}" \
                   --jenkinsJob "${JENKINS_JOB_INFO}"
        else
            python plinth-ci-job-creator.py "$FTP_SERVER/${TREE_NAME}/${GIT_DESCRIBE}/${PLAT}-${board_arch}/" \
                   --tree "${TREE_NAME}" --plans "$test_name" --arch "${board_arch}" \
                   --testUrl "${TEST_REPO}" --testDir "${TEST_CASE_DIR}" --plan "${TEST_PLAN}" --scope "${TEST_SCOPE}" --level "${TEST_LEVEL}" \
                   --jekinsJob "${JENKINS_JOB_INFO}"
        fi
    done
}

function run_and_report_jobs() {
    local distro=$1
    if [ x"$distro" == x"" ]; then
        echo "distro can't be null! Aborting"
        return -1
    fi

    if [ x"$SKIP_LAVA_RUN" = x"false" ];then
        pushd ${JOBS_DIR}
        python ../estuary-job-runner.py --username $LAVA_USER --token $LAVA_TOKEN --server $LAVA_SERVER --stream $LAVA_STREAM --poll POLL
        popd

        if [ ! -f ${JOBS_DIR}/${RESULTS_DIR}/POLL ]; then
            echo "Running jobs error! Aborting"
            return -1
        else
            echo "POLL Result:"
            cat ${JOBS_DIR}/${RESULTS_DIR}/POLL
            JOB_ID=`cat ${JOBS_DIR}/${RESULTS_DIR}/POLL | grep bundle | awk -F"'" '{print $2}'`
            JOB_RESULT_MAIL=`cat ${JOBS_DIR}/${RESULTS_DIR}/POLL | grep bundle | awk -F"," '{print $2}' | awk -F'}' '{print $1}'`
        fi

        python ${script_path}/plinth-report.py --boot ${JOBS_DIR}/${RESULTS_DIR}/POLL --lab $LAVA_USER --testDir "${TEST_CASE_DIR}" --distro "$distro"
        if [ ! -d ${RESULTS_DIR} ]; then
            echo "running jobs error! Aborting"
            return -1
        fi
    else
        echo "skip lava run and report"
    fi
}

function judge_pass_or_not() {
    FAIL_FLAG=$(grep -R 'FAIL' ./${JOBS_DIR}/${RESULTS_DIR}/POLL || true)
    if [ "$FAIL_FLAG"x != ""x ]; then
        echo "jobs fail"
        return -1
    fi

    PASS_FLAG=$(grep -R 'PASS' ./${JOBS_DIR}/${RESULTS_DIR}/POLL || true)
    if [ "$PASS_FLAG"x = ""x ]; then
        echo "jobs fail"
        return -1
    fi
    return 0
}

function run_and_move_result() {
    test_name=$1
    dest_dir=$2
    ret_val=0

    if ! run_and_report_jobs "${dest_dir}";then
        ret_val=-1
    fi

    if ! judge_pass_or_not ; then
        ret_val=-1
    fi

    [ ! -d ${dest_dir} ] && mkdir -p ${dest_dir}

    [ -e ${WHOLE_SUM} ] && mv ${WHOLE_SUM} ${dest_dir}/
    [ -e ${DETAILS_SUM} ] && mv ${DETAILS_SUM} ${dest_dir}/

    [ -e ${SCOPE_SUMMARY_NAME} ] && mv ${SCOPE_SUMMARY_NAME} ${dest_dir}/
    [ -e ${PDF_FILE} ] && mv ${PDF_FILE} ${dest_dir}/

    [ -e ${RESULT_JSON} ] && mv ${RESULT_JSON} ${dest_dir}/

    [ -d ${JOBS_DIR} ] && mv ${JOBS_DIR} ${dest_dir}/${JOBS_DIR}_${test_name}
    [ -d ${RESULTS_DIR} ] && mv ${RESULTS_DIR} ${dest_dir}/${RESULTS_DIR}_${test_name}

    if [ "$ret_val" -ne 0 ]; then
        return -1
    else
        return 0
    fi
}

#######  Begining the tests ######

function init_summaryfile() {
    if [ -f ${WORKSPACE}/${WHOLE_SUM} ]; then
        rm -rf ${WORKSPACE}/${WHOLE_SUM}
    else
        touch ${WORKSPACE}/${WHOLE_SUM}
    fi
}

function parse_arch_map() {
    read -a arch <<< $(echo $ARCH_MAP)
    declare -A -g dict
    for((i=0; i<${#arch[@]}; i++)); do
        if ((i%2==0)); then
            j=`expr $i+1`
            dict[${arch[$i]}]=${arch[$j]}
        fi
    done

    for key in "${!dict[@]}"; do echo "$key - ${dict[$key]}"; done
}

function clean_workspace() {
    ##### remove all file from the workspace #####
    rm -rf ${CI_SCRIPTS_DIR}/uef* || true

    rm -rf test_result.tar.gz || true
    rm -rf ${WORKSPACE}/*.txt || true
    rm -rf ${WORKSPACE}/*.log || true
    rm -rf ${WORKSPACE}/*.html || true
    rm -rf ${WORKSPACE}/html/*.html || true

    ### reset CI scripts ####
    cd ${CI_SCRIPTS_DIR}/; git clean -fdx; cd -
}

function trigger_lava_build() {
    pushd ${WORKSPACE}/local/ci-scripts/test-scripts
    mkdir -p ${GIT_DESCRIBE}/${RESULTS_DIR}
    for DISTRO in $SHELL_DISTRO; do
        if [ -d $DISTRO ];then
            rm -fr $DISTRO
        fi

        for boot_plan in $BOOT_PLAN; do
            rm -fr ${JOBS_DIR} ${RESULTS_DIR}

            # generate the boot jobs for all the targets
            if [ "$boot_plan" = "BOOT_ISO" ]; then
                # pxe install in previous step.use ssh to do the pxe test.
                # BOOT_ISO
                # boot from ISO
                generate_jobs $boot_plan $DISTRO

                if [ -d ${JOBS_DIR} ]; then
                    if ! run_and_move_result $boot_plan $DISTRO ;then
                        if [ ! -d ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO} ];then
                            mv ${DISTRO} ${GIT_DESCRIBE}/${RESULTS_DIR}
                            continue
                        else
                            cp -fr ${DISTRO}/* ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/
                            continue
                        fi
                    fi
                fi
            elif [ "$boot_plan" = "BOOT_PXE" ]; then
                # pxe install in previous step.use ssh to do the pxe test.
                # BOOT_PXE
                # boot from PXE
                generate_jobs $boot_plan $DISTRO

                if [ -d ${JOBS_DIR} ]; then
                    if ! run_and_move_result $boot_plan $DISTRO ;then
                        if [ ! -d ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO} ];then
                            mv ${DISTRO} ${GIT_DESCRIBE}/${RESULTS_DIR}
                            continue
                        else
                            cp -fr ${DISTRO}/* ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/
                            continue
                        fi
                    fi
                fi
            else
                # BOOT_NFS
                # boot from NFS
                generate_jobs $boot_plan $DISTRO

                if [ -d ${JOBS_DIR} ]; then
                    if ! run_and_move_result $boot_plan $DISTRO ;then
                        if [ ! -d ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO} ];then
                            mv ${DISTRO} ${GIT_DESCRIBE}/${RESULTS_DIR}
                            continue
                        else
                            cp -fr ${DISTRO}/* ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/
                            continue
                        fi
                    fi
                fi
            fi
        done
        if [ ! -d $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO} ];then
            mv ${DISTRO} $GIT_DESCRIBE/${RESULTS_DIR} && continue
        else
            cp -fr ${DISTRO}/* $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO}/ && continue
        fi
    done
    popd
}

function tar_test_result() {
    pushd ${WORKSPACE}/local/ci-scripts/test-scripts
    tar czf test_result.tar.gz ${GIT_DESCRIBE}/*
    cp test_result.tar.gz  ${WORKSPACE}
    popd
}

function collect_result() {
    # push the binary files to the ftpserver
    pushd ${WORKSPACE}/local/ci-scripts/test-scripts
    DES_DIR=${FTP_DIR}/${TREE_NAME}/${GIT_DESCRIBE}/
    [ ! -d $DES_DIR ] && echo "Don't have the images and dtbs" && exit -1

    if [ -e  ${WORKSPACE}/${WHOLE_SUM} ]; then
        rm -rf  ${WORKSPACE}/${WHOLE_SUM}
    fi

    if [ -e  ${WORKSPACE}/${DETAILS_SUM} ]; then
        rm -rf  ${WORKSPACE}/${DETAILS_SUM}
    fi

    if [ -e  ${WORKSPACE}/${PDF_FILE} ]; then
        rm -rf  ${WORKSPACE}/${PDF_FILE}
    fi

    if [ -e  ${WORKSPACE}/${SCOPE_SUMMARY_NAME} ]; then
        rm -rf  ${WORKSPACE}/${SCOPE_SUMMARY_NAME}
    fi

    if [ -e  ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM} ]; then
        rm -rf  ${GIT_DESCRIBE}/${RESULTS_DIR}/${WHOLE_SUM}
    fi

    cd ${GIT_DESCRIBE}/${RESULTS_DIR}
    distro_dirs=$(ls -d */ | cut -f1 -d'/')
    cd -

    for distro_name in ${distro_dirs};do
        # add distro info in txt file
        # sed -i -e 's/^/'"${distro_name}"' /' ${CI_SCRIPTS_DIR}/test-scripts/${GIT_DESCRIBE}/${RESULTS_DIR}/${distro_name}/${DETAILS_SUM}
		if [ -e  ${CI_SCRIPTS_DIR}/test-scripts/${GIT_DESCRIBE}/${RESULTS_DIR}/${distro_name}/${DETAILS_SUM} ]; then
			cat ${CI_SCRIPTS_DIR}/test-scripts/${GIT_DESCRIBE}/${RESULTS_DIR}/${distro_name}/${DETAILS_SUM} >> ${GIT_DESCRIBE}/${RESULTS_DIR}/${DETAILS_SUM}
		fi
    done

    # apt-get install pdftk
    # pdftk file1.pdf file2.pdf cat output output.pdf
    cp ${GIT_DESCRIBE}/${RESULTS_DIR}/${DETAILS_SUM} ${WORKSPACE}/${DETAILS_SUM}

    cp -rf ${timefile} ${WORKSPACE} || true

    #zip -r ${{GIT_DESCRIBE}}_results.zip ${GIT_DESCRIBE}/*
    cp -f ${timefile} ${GIT_DESCRIBE} || true

    # if DEBUG is set, don't update the result
    if [ ! "${DEBUG}" = "true" ];then
        if [ -d $DES_DIR/${GIT_DESCRIBE}/results ];then
            sudo rm -fr $DES_DIR/${GIT_DESCRIBE}/results
            sudo rm -fr $DES_DIR/${GIT_DESCRIBE}/${timefile}
        fi
        sudo cp -rf ${GIT_DESCRIBE}/* $DES_DIR
    fi

    popd    # restore current work directory

    cat ${timefile}
}

function init_env() {
    CI_SCRIPTS_DIR=${WORKSPACE}/local/ci-scripts
    TEST_CASE_DIR=${WORKSPACE}/local/plinth-test-suite
}


function show_help(){
    :
}

function parse_input() {
    # A POSIX variable
    OPTIND=1         # Reset in case getopts has been used previously in the shell.

    # Initialize our own variables:
    properties_file=""

    while getopts "h?p:" opt; do
        case "$opt" in
            h|\?)
                show_help
                exit 0
                ;;
            p)  PROPERTIES_FILE=$OPTARG
                ;;
        esac
    done

    shift $((OPTIND-1))

    [ "$1" = "--" ] && shift

    echo "properties_file='$properties_file', Leftovers: $@"
}

function generate_failed_mail(){
    cd ${WORKSPACE}
    echo "${FAILED_MAIL_LIST}" > MAIL_LIST.txt
    echo "${FAILED_MAIL_CC_LIST}" > MAIL_CC_LIST.txt
    echo "Estuary CI - ${GIT_DESCRIBE} - Failed" > MAIL_SUBJECT.txt
    cat > MAIL_CONTENT.txt <<EOF
( This mail is send by Jenkins automatically, don't reply ) <br>
Project Name: ${TREE_NAME} <br>
Version: ${GIT_DESCRIBE} <br>
Boot and Test Status: failed <br>
Deploy Type: ${BOOT_PLAN} <br>
Build Log Address: ${BUILD_URL}console <br>
Build Project Address: $BUILD_URL <br>
Build and Generated Binaries Address:${FTPSERVER_DISPLAY_URL}/open-estuary/${GIT_DESCRIBE} <br>
The Test Cases Definition Address: ${TEST_REPO}<br>
<br>
The boot and test is failed unexpectly. Please check the log and fix it.<br>
<br>
EOF

}

# export FTP_DIR="/fileserver"; export TREE_NAME="open-estuary"; export month=201804
function generate_pass_rate() {
    month=$(date +"%Y%m")
    day=$(date +"%d")

    release_list=$(ls ${FTP_DIR}/${TREE_NAME}/ | grep "$month" || true)
    success_day=$(echo ${release_list} | wc -w)
    rate=$(echo "${success_day} * 100 / ${day}" | bc)
    echo ${rate}
}

# export FTP_DIR="/fileserver"; export TREE_NAME="open-estuary"; export DETAILS_SUM='details_summary.txt'
function generate_test_rate() {
    month=$(date +"%Y%m")
    day=$(date +"%d")

    release_list=$(ls ${FTP_DIR}/${TREE_NAME}/ | grep "$month" || true)
    success_day=0
    for release in ${release_list};do
        if [ -e ${FTP_DIR}/${TREE_NAME}/${release}/results/${DETAILS_SUM} ];then
           if ! grep -qE 'fail$' ${FTP_DIR}/${TREE_NAME}/${release}/results/${DETAILS_SUM};then
               success_day=$((success_day + 1))
           fi
        fi
    done
    rate=$(echo "${success_day} * 100 / ${day}" | bc)
    echo ${rate}
}

function generate_success_mail(){
    echo "###################### start generate mail ####################"
	
	path=$(cd "`dirname $0`";pwd)
	pushd ${path}
	
    # prepare parameters
	
	#all file used to be generate mail is to be save in mail document
	mkdir -p mail
	
	for DISTRO in $SHELL_DISTRO; do
		mkdir mail/${DISTRO}
		
		#whole_sum.txt record the daily test report for 今日构建结果
		cp ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/${WHOLE_SUM} mail/${DISTRO}/whole_sum.txt
		
		#detail_sum.txt record the result of all test case have run this time
		cp ${GIT_DESCRIBE}/${RESULTS_DIR}/${DETAILS_SUM} mail/detail_sum.txt
	done
	
    echo "${SUCCESS_MAIL_LIST}" > mail/MAIL_LIST.txt
    echo "${SUCCESS_MAIL_CC_LIST}" > mail/MAIL_CC_LIST.txt

    TODAY=$(date +"%Y/%m/%d")
    MONTH=$(date +"%Y%m")

    # the result dir path ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/

    # set job result by
    JOB_RESULT=PASS
    if [ -e mail/detail_sum.txt ];then
        if cat mail/detail_sum.txt | grep -q "\(fail\|FAIL\)$";then
            JOB_RESULT=FAIL
        fi

        if cat mail/detail_sum.txt | grep -q "\(pass\|PASS\)$";then
            :
        else
            JOB_RESULT=FAIL
        fi
    else
        JOB_RESULT=FAIL
    fi

    # echo all mail releated info
    echo_vars TODAY GIT_DESCRIBE JOB_RESULT TREE_NAME BOOT_PLAN BUILD_URL FTPSERVER_DISPLAY_URL TEST_REPO

    echo "------------------------------------------------------------"


    echo "Plinth CI Auto-test Daily Report (${TODAY}) - ${JOB_RESULT}" > mail/MAIL_SUBJECT.txt

    echo "<b>Plinth CI Auto-test Daily Report (${TODAY})</b><br>" > mail/MAIL_CONTENT.txt
    echo "<br>" >> mail/MAIL_CONTENT.txt
    echo "<br>" >> mail/MAIL_CONTENT.txt
    echo "<b>1. 构建信息</b><br>" >> mail/MAIL_CONTENT.txt

    JOB_INFO_VERSION="Plinth V1.0 - ${TODAY}"
    # TODO : the start time need read from file.
    JOB_INFO_SHA1=${BRANCH_NAME}#"${GIT_DESCRIBE}"
    JOB_INFO_RESULT=${JOB_RESULT}
    JOB_INFO_START_TIME="${JENKINS_JOB_START_TIME}"
    JOB_INFO_END_TIME=$(current_time)
    export_vars JOB_INFO_VERSION JOB_INFO_SHA1 JOB_INFO_RESULT JOB_INFO_START_TIME JOB_INFO_END_TIME
    envsubst < ./html/1-job-info-table.json > ./html/1-job-info-table.json.tmp
    python ./html/html-table.py -f ./html/1-job-info-table.json.tmp >> mail/MAIL_CONTENT.txt
    rm -f ./html/1-job-info-table.json.tmp
    echo "<br><br>" >> mail/MAIL_CONTENT.txt

    echo "<b>2. 今日构建结果</b><br>" >> mail/MAIL_CONTENT.txt
    JOB_RESULT_VERSION="Plinth ${BRANCH_NAME}"
    JOB_RESULT_DATA=""
    for DISTRO in $SHELL_DISTRO; do
        JOB_RESULT_DATA=$(< mail/${DISTRO}/whole_sum.txt)",${JOB_RESULT_DATA}"
    done
    JOB_RESULT_DATA="${JOB_RESULT_DATA%,}"
    export_vars JOB_RESULT_VERSION JOB_RESULT_DATA
    envsubst < ./html/2-job-result-table.json > ./html/2-job-result-table.json.tmp
    python ./html/html-table.py -f ./html/2-job-result-table.json.tmp >> mail/MAIL_CONTENT.txt
    rm -f ./html/2-job-result-table.json.tmp
    echo "<br><br>" >> mail/MAIL_CONTENT.txt

  # generate distro html
  for DISTRO in $SHELL_DISTRO; do
      detail_html_generate "${GIT_DESCRIBE}/${RESULTS_DIR}/${DETAILS_SUM}" "${WORKSPACE}/html/TestReport" "${DISTRO}"
  done

  echo "<br><br>" >> mail/MAIL_CONTENT.txt


  ##  编译结果
  touch ${WORKSPACE}/html/BuildReport.html
  # TODO : add build result into the build.html
  #cd -

  #copy the Mail txt to workspace document
  cp mail/MAIL_LIST.txt ${WORKSPACE}/MAIL_LIST.txt
  cp mail/MAIL_CC_LIST.txt ${WORKSPACE}/MAIL_CC_LIST.txt
  cp mail/MAIL_CONTENT.txt ${WORKSPACE}/MAIL_CONTENT.txt
  cp mail/MAIL_SUBJECT.txt ${WORKSPACE}/MAIL_SUBJECT.txt
  
  mkdir -p /home/luojiaxing/mail
 
  if [ ! -f /home/luojiaxing/mail/TEST_LIST.txt ];then
	touch /home/luojiaxing/mail/TEST_LIST.txt
	cat "luojiaxing@huawei.com,1191097880@qq.com,huangdaode@hisilicon.com,tanhuazhong@huawei.com" > TEST_LIST.txt
  fi

  #cat "luojiaxing@huawei.com,1191097880@qq.com,huangdaode@hisilicon.com" > TEST_LIST.txt
  #cat "tanhuazhong@huawei.com,linyunsheng@huawei.com,chenjing92@hisilicon.com" >> TEST_LIST.txt
  
  cp mail/MAIL_LIST.txt /home/luojiaxing/mail/MAIL_LIST.txt
  #cp /home/luojiaxing/mail/TEST_LIST.txt /home/luojiaxing/mail/MAIL_LIST.txt
  cp mail/MAIL_CC_LIST.txt /home/luojiaxing/mail/MAIL_CC_LIST.txt
  cp mail/MAIL_CONTENT.txt /home/luojiaxing/mail/MAIL_CONTENT.txt
  cp mail/MAIL_SUBJECT.txt /home/luojiaxing/mail/MAIL_SUBJECT.txt
  
  cp ${WORKSPACE}/MAIL_CONTENT.txt ${WORKSPACE}/html/DailyReport.html
  
  rm -rf mail
  echo "######################################## generate mail success ########################################"
}

# detail_html_generate ${type} ${source_data} ${target_html}
# type : total pass fail block
# will automaticlly add html
function detail_html_generate() {
    local source_data=$1
    local target_html=$2
    local distro=$3

    mkdir -p ${WORKSPACE}/html/

    AWK_SCRIPT='{
                    print "<tr style=\"text-align: center;justify-content: center;font-size:12px;\">";
                    print "<td style=\"padding:10px;\">" NR "</td>";
                    print "<td style=\"padding:10px;\"><a href=\"" "'"${LAVA_DISPLAY_URL}/results/"'" $4 "\">" $4 "</a></td>";
                    print "<td style=\"padding:10px;\">" substr($5,3,length($5)) "</td>";
                    print "<td style=\"padding:10px;\">" $6 "</td>";
                    print "<td style=\"padding:10px;\"><a href=\"" "'"${LAVA_DISPLAY_URL}/results/"'" $4 "\"> LINK </a></td>";
                    print "<td style=\"padding:10px;\">";
                    if ($7 == "pass")
                        print "<font color=\"green\">" $7 "</font>";
                    else
                        print "<font color=\"red\">" $7 "</font>";
                    print "</td></tr>"; }'

    if [ -z "${distro}" ];then
        # total
        detail_html_header "${target_html}.html"
        cat ${source_data} |
            awk -F" " "${AWK_SCRIPT}" >> "${target_html}.html"
        detail_html_footer "${target_html}.html"

        # pass
        detail_html_header "${target_html}_pass.html"
        cat ${source_data} | grep "pass$" |
            awk -F" " "${AWK_SCRIPT}" >> "${target_html}_pass.html"
        detail_html_footer "${target_html}_pass.html"

        # fail
        detail_html_header "${target_html}_fail.html"
        cat ${source_data} | grep "fail$" |
            awk -F" " "${AWK_SCRIPT}" >> "${target_html}_fail.html"
        detail_html_footer "${target_html}_fail.html"
    else
        set +x
        echo "#################### strat generate distro and module html page ####################"
        distro_source_data=$(cat ${source_data} | grep "^${distro}" || true)
        # total
        detail_html_header "${target_html}_${distro}.html"
        echo "${distro_source_data}" |
            awk -F" " "${AWK_SCRIPT}" >> "${target_html}_${distro}.html"
        detail_html_footer "${target_html}_${distro}.html"

        # pass
        detail_html_header "${target_html}_${distro}_pass.html"
        echo "${distro_source_data}" | grep "pass$" |
            awk -F" " "${AWK_SCRIPT}" >> "${target_html}_${distro}_pass.html"
        detail_html_footer "${target_html}_${distro}_pass.html"

        # fail
        detail_html_header "${target_html}_${distro}_fail.html"
        echo "${distro_source_data}" | grep "fail$" |
            awk -F" " "${AWK_SCRIPT}" >> "${target_html}_${distro}_fail.html"
        detail_html_footer "${target_html}_${distro}_fail.html"

        all_modules=$(echo "${distro_source_data}" | awk -F" " '{print $3}' | uniq)
        if [ -n "${all_modules}" ];then
            for module in ${all_modules};do
                # total
                detail_html_header "${target_html}_Z_${distro}_${module}.html"
                echo "${distro_source_data}" | grep -P "^[a-zA-Z0-9]+\t[a-zA-Z0-9]+\t${module}\t" |
                    awk -F" " "${AWK_SCRIPT}" >> "${target_html}_Z_${distro}_${module}.html"
                detail_html_footer "${target_html}_Z_${distro}_${module}.html"

                # pass
                detail_html_header "${target_html}_Z_${distro}_${module}_pass.html"
                echo "${distro_source_data}" | grep -P "^[a-zA-Z0-9]+\t[a-zA-Z0-9]+\t${module}\t" | grep "pass$" |
                    awk -F" " "${AWK_SCRIPT}" >> "${target_html}_Z_${distro}_${module}_pass.html"
                detail_html_footer "${target_html}_Z_${distro}_${module}_pass.html"

                # fail
                detail_html_header "${target_html}_Z_${distro}_${module}_fail.html"
                echo "${distro_source_data}" | grep -P "^[a-zA-Z0-9]+\t[a-zA-Z0-9]+\t${module}\t" | grep "fail$" |
                    awk -F" " "${AWK_SCRIPT}" >> "${target_html}_Z_${distro}_${module}_fail.html"
                detail_html_footer "${target_html}_Z_${distro}_${module}_fail.html"
            done
        fi
        set -x
    fi
}

function detail_html_header() {
    local target_html=$1
    touch ${target_html}
    echo '<table width="90%" cellspacing="0px" cellpadding="10px" border="1"  style="border: solid 1px black; border-collapse:collapse; word-break:keep-all; text-align:center;">' > ${target_html}
    echo '<tr style="text-align:center; justify-content:center; background-color:#D2D4D5; text-align:center; font-size:15px; font-weight=bold;padding:10px">
              <th style="padding:10px;">NO</th>
              <th style="padding:10px;">Job ID</th>
              <th style="padding:10px;">Suite Name</th>
              <th style="padding:10px;">Case Name</th>
              <th style="padding:10px;">Log</th>
              <th style="padding:10px;">Case Result</th></tr>' >> ${target_html}
}

function detail_html_footer() {
    local target_html=$1
    echo "</table>" >> ${target_html}
}


#$1:  LAVA JOB ID used to contruct url for result
#$2:  LAVA RESULT 
function generate_simple_mail(){
    local tid=$1
    local result=$2
    echo "${SUCCESS_MAIL_LIST}" > ${WORKSPACE}/MAIL_LIST.txt
    echo "${SUCCESS_MAIL_CC_LIST}" > ${WORKSPACE}/MAIL_CC_LIST.txt
    echo "Plinth CI D06 ${GIT_DESCRIBE} Result" > ${WORKSPACE}/MAIL_SUBJECT.txt
    cat > ${WORKSPACE}/MAIL_CONTENT.txt <<EOF
( This mail is send by Jenkins automatically, don't reply )<br>
Project Name: ${TREE_NAME}<br>
Version: ${GIT_DESCRIBE}<br>
Test Result Address: http://120.31.149.194:180/results/${tid}<br>
<br>
EOF
}

function main() {
    set_timezone_china

    parse_input "$@"
    source_properties_file "${PROPERTIES_FILE}"

    init_timefile test

    init_workspace
    init_build_option

    init_env
    init_boot_env

    init_input_params
    parse_params

    generate_failed_mail
    save_properties_and_result fail

    prepare_tools

    print_time "time_test_test_begin"
    init_summaryfile

    ##### copy some files to the lava-server machine to support the boot process #####
    parse_arch_map
    clean_workspace
    print_time "time_preparing_envireonment"

    trigger_lava_build

    collect_result

    #print_time "time_test_test_end"

    #save_properties_and_result pass

    generate_success_mail
    #generate_simple_mail ${JOB_ID} ${JOB_RESULT_MAIL}
}

main "$@"
