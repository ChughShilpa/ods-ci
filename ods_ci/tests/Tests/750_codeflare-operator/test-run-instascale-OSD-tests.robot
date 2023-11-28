*** Settings ***
Documentation   InstaScale tests

Resource         ../../../tasks/Resources/RHODS_OLM/install/codeflare_install.resource
Resource         ../../Resources/Page/codeflare-operator/codeflare-operator.resource

*** Variables ***
${CFO_DIR}                    codeflare-operator
${CFO_TEST_RESULT_FILE}    %{WORKSPACE=.}/codeflare-test-results.txt
${CFO_JUNIT_FILE}          %{WORKSPACE=.}/junit.xml
${CFO_TEST_TYPE}    TestInstascaleMachinePool


*** Test Cases ***
Run instascale machine pool tests
    [Documentation]   Run instascale machine pool tests located in codeflare_operator repo
    [Tags]  ODS-2513

    Skip If Component Is Not Enabled    codeflare
    codeflare-operator.Clone Git Repository    %{CFO_GIT_REPO}    %{CFO_GIT_REPO_BRANCH}    ${CFO_DIR}
    ${test_result}=    Run Codeflare Tests    ${CFO_DIR}    ${CFO_TEST_RESULT_FILE}    ${CFO_TEST_TYPE}
    IF    ${test_result} != 0
        FAIL    There were test failures in the Distributed Workloads tests.
    END