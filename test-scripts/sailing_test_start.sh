#!/bin/bash -x
# -*- coding: utf-8 -*-

#: Title                  : jenkins_boot_start.sh
#: Usage                  : ./local/ci-scripts/test-scripts/jenkins_boot_start.sh -p env.properties
#: Author                 : qinsl0106@thundersoft.com
#: Description            : CI中 测试部分 的jenkins任务脚本

__ORIGIN_PATH__="$PWD"
script_path="${0%/*}"  # remove the script name ,get the path
script_path=${script_path/\./$(pwd)} # if path start with . , replace with $PWD
source "${script_path}/../common-scripts/common.sh"

WORKSPACE=${script_path}/../../../
CI_SCRIPTS_DIR="WORKSPACE/local/scripts"
#SHELL_PLATFORM="d05"


function parse_params() {
    pushd ${CI_SCRIPTS_DIR}
    : ${SHELL_PLATFORM:=`python configs/parameter_parser.py -f config.yaml -s Build -k Platform`}
    : ${SHELL_DISTRO:=`python configs/parameter_parser.py -f config.yaml -s Build -k Distro`}
    : ${BOOT_PLAN:=`python configs/parameter_parser.py -f config.yaml -s Jenkins -k Boot`}

    : ${TEST_PLAN:=`python configs/parameter_parser.py -f config.yaml -s Test -k Plan`}
    : ${TEST_SCOPE:=`python configs/parameter_parser.py -f config.yaml -s Test -k Scope`}
    : ${TEST_REPO:=`python configs/parameter_parser.py -f config.yaml -s Test -k Repo`}
    : ${TEST_LEVEL:=`python configs/parameter_parser.py -f config.yaml -s Test -k Level`}

    : ${LAVA_SERVER:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k lavaserver`}
    : ${LAVA_USER:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k lavauser`}
    : ${LAVA_STREAM:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k lavastream`}
    : ${LAVA_TOKEN:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k TOKEN`}

    : ${LAVA_DISPLAY_URL:=`python configs/parameter_parser.py -f config.yaml -s LAVA -k LAVA_DISPLAY_URL`}

    : ${FTP_SERVER:=`python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k ftpserver`}
    : ${FTPSERVER_DISPLAY_URL:=`python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k FTPSERVER_DISPLAY_URL`}
    : ${FTP_DIR:=`python configs/parameter_parser.py -f config.yaml -s Ftpinfo -k FTP_DIR`}

    : ${ARCH_MAP:=`python configs/parameter_parser.py -f config.yaml -s Arch`}

    : ${SUCCESS_MAIL_LIST:=`python configs/parameter_parser.py -f config.yaml -s Mail -k SUCCESS_LIST`}
    : ${SUCCESS_MAIL_CC_LIST:=`python configs/parameter_parser.py -f config.yaml -s Mail -k SUCCESS_CC_LIST`}
    : ${FAILED_MAIL_LIST:=`python configs/parameter_parser.py -f config.yaml -s Mail -k FAILED_LIST`}
    : ${FAILED_MAIL_CC_LIST:=`python configs/parameter_parser.py -f config.yaml -s Mail -k FAILED_CC_LIST`}

    popd    # restore current work directory
}

function generate_jobs() {
    local test_name=$1
    local distro=$2

    pwd
    for PLAT in $SHELL_PLATFORM; do
        board_arch="arm64"
        if [ x"$distro" != x"" ]; then
            python estuary-ci-job-creator.py "$FTP_SERVER/${TREE_NAME}/${GIT_DESCRIBE}/${PLAT}-${board_arch}/" \
                   --tree "${TREE_NAME}" --plans "$test_name" --distro "$distro" --arch "${board_arch}" \
                   --testUrl "${TEST_REPO}" --testDir "${TEST_CASE_DIR}" --plan "${TEST_PLAN}" --scope "${TEST_SCOPE}" --level "${TEST_LEVEL}" \
                   --jenkinsJob "${JENKINS_JOB_INFO}"
        else
            python estuary-ci-job-creator.py "$FTP_SERVER/${TREE_NAME}/${GIT_DESCRIBE}/${PLAT}-${board_arch}/" \
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
        fi

        python estuary-report.py --boot ${JOBS_DIR}/${RESULTS_DIR}/POLL --lab $LAVA_USER --testDir "${TEST_CASE_DIR}" --distro "$distro" --scope "${TEST_SCOPE}" --level "${TEST_LEVEL}" --plan "${TEST_PLAN}" 
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

function trigger_lava_build() {
    pushd ${WORKSPACE}/local/ci-scripts/test-scripts
    mkdir -p ${GIT_DESCRIBE}/${RESULTS_DIR}
    cp /fileserver/open-estuary/${GIT_DESCRIBE}/compile_result.txt ./ #use jenkins plugin to transmit result file
    for DISTRO in $SHELL_DISTRO; do
        if [ -d $DISTRO ];then
            rm -fr $DISTRO
        fi
	cat ./compile_result.txt |sed -n "/${DISTRO,,}:pass/p" > ./compile_tmp.log
	if [ -s ./compile_tmp.log ] ; then
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
                                #continue
                            else
                                cp -fr ${DISTRO}/* ${GIT_DESCRIBE}/${RESULTS_DIR}/${DISTRO}/
                                #continue
                            fi
                        fi
			replace_whole_sum_file $DISTRO
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
			replace_whole_sum_file $DISTRO
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

#add by yuhua 9513 
#modi whole sum file to show really total case and unrun case num.
function replace_whole_sum_file() {
    local distro=$1
    pushd ${CI_SCRIPTS_DIR}/test-scripts/
    if [ -d $distro ];then
        cd $distro
        total_case=`cat ${CI_SCRIPTS_DIR}/test-scripts/total_sum.txt |awk -F ':' '{print $2}'`
        or_case=`cat whole_summary.txt |awk -F ',' '{print $4}'|awk -F ' ' '{print $2}'`
        total_num=`echo $total_case | awk '{split($0,a,"\"");print a[2];}'`
        or_num=`echo $or_case | awk '{split($0,a,"\"");print a[2];}'`
        untest_num=`expr $total_num - $or_num`
        #sed -i "s/$or_case/${total_case}/" ./${WHOLE_SUM}
        zero_num=`grep -o '"0"' whole_summary.txt |wc -l`
	pass_case=`cat whole_summary.txt |awk -F ',' '{print $7}'|awk -F ' ' '{print $2}'`
        pass_num=`echo $pass_case | awk '{split($0,a,"\"");print a[2];}'`
	if [ $total_num -gt $or_num ]; then
	    ac_pass_rate=`awk 'BEGIN{printf "%.2f%\n",'$pass_num'/'$total_num'*100}'`
            sed -i "s/$or_case/${total_case}/1" ./${WHOLE_SUM}   #replace or_case with total-case
            if [ x"$zero_num" = x"2" ]; then
	        sed -i "s/\"0\"/\"${untest_num}\"/2" ./${WHOLE_SUM}
            else
	        sed -i "s/\"0\"/\"${untest_num}\"/1" ./${WHOLE_SUM}
            fi
	else
	    ac_pass_rate=`awk 'BEGIN{printf "%.2f%\n",'$pass_num'/'$or_num'*100}'`
	    echo "the total caes num is not correct,skip the replacement."
        fi
#    sed -i 's/"o", "color": "orange"/"rep", "color": "orange"/' ./${WHOLE_SUM}  #use template to get location 
#    sed -i "s/rep/${untest_num}/" ./${WHOLE_SUM} #repace unrun case num with actual num
        echo "the actually unrun case is:${untest_num}"
	or_pass_rate=`cat whole_summary.txt |awk -F ',' '{print $6}'`
        sed -i "s/${or_pass_rate}/ \"${ac_pass_rate}\"/1" ./${WHOLE_SUM} 	
        cd -
    else
	cd ${GIT_DESCRIBE}/${RESULTS_DIR}/$distro
	total_case=`cat ${CI_SCRIPTS_DIR}/test-scripts/total_sum.txt |awk -F ':' '{print $2}'`
        or_case=`cat whole_summary.txt |awk -F ',' '{print $4}'|awk -F ' ' '{print $2}'`
        total_num=`echo $total_case | awk '{split($0,a,"\"");print a[2];}'`
        or_num=`echo $or_case | awk '{split($0,a,"\"");print a[2];}'`
        untest_num=`expr $total_num - $or_num`
        #sed -i "s/$or_case/${total_case}/" ./${WHOLE_SUM}
        zero_num=`grep -o '"0"' whole_summary.txt |wc -l`
        pass_case=`cat whole_summary.txt |awk -F ',' '{print $7}'|awk -F ' ' '{print $2}'`
        pass_num=`echo $pass_case | awk '{split($0,a,"\"");print a[2];}'`
	if [ $total_num -gt $or_num ]; then
	    ac_pass_rate=`awk 'BEGIN{printf "%.2f%\n",'$pass_num'/'$total_num'*100}'`
            sed -i "s/$or_case/${total_case}/1" ./${WHOLE_SUM}   #replace or_case with total-case
            if [ x"$zero_num" = x"2" ]; then
                sed -i "s/\"0\"/\"${untest_num}\"/2" ./${WHOLE_SUM}
            else
                sed -i "s/\"0\"/\"${untest_num}\"/1" ./${WHOLE_SUM}
            fi
	else
            ac_pass_rate=`awk 'BEGIN{printf "%.2f%\n",'$pass_num'/'$or_num'*100}'`
            echo "the total case num is not correct ,skip the replacement."
	fi
#    sed -i 's/"o", "color": "orange"/"rep", "color": "orange"/' ./${WHOLE_SUM}  #use template to get location
#    sed -i "s/rep/${untest_num}/" ./${WHOLE_SUM} #repace unrun case num with actual num
        echo "the actually unrun case is:${untest_num}"
        or_pass_rate=`cat whole_summary.txt |awk -F ',' '{print $6}'`
        sed -i "s/${or_pass_rate}/ \"${ac_pass_rate}\"/1" ./${WHOLE_SUM}
        cd -

    fi	
    popd
  
}

function init_env() {
    CI_SCRIPTS_DIR=${WORKSPACE}/local/ci-scripts
    TEST_CASE_DIR=${WORKSPACE}/local/ci-test-cases
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

function main() {
    set_timezone_china
    init_timefile test

    generate_failed_mail
    #save_properties_and_result fail
    print_time "time_test_test_begin"

    ##### copy some files to the lava-server machine to support the boot process #####
    print_time "time_preparing_envireonment"

    trigger_lava_build
   # generate_distro_file
    collect_result

    print_time "time_test_test_end"

    #save_properties_and_result pass

    generate_success_mail
}

main "$@"
