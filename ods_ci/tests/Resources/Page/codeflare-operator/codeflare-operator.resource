*** Settings ***
Documentation    This is a resource file for codeflare-operator
Library          OperatingSystem
Library          Process

*** Variables ***
${CODEFLARE_TEST_TIMEOUT_LONG}    20m
${GO_TEST_TIMEOUT}    30m
${CLUSTER_TYPE}    OSD
${CLUSTERID}    26u473e1nntseev25iqqvl3blnsr1kdb


*** Keywords ***
Clone Git Repository
    [Documentation]   Clone Git repository
    [Arguments]    ${CFO_REPO_URL}    ${CFO_REPO_BRANCH}    ${CFO_DIR}
    ${result} =    Run Process    git clone -b ${CFO_REPO_BRANCH} ${CFO_REPO_URL} ${CFO_DIR}
    ...    shell=true    stderr=STDOUT
    Log To Console    ${result.stdout}
    IF    ${result.rc} != 0
        FAIL    Unable to clone CFO repo ${CFO_REPO_URL}:${CFO_REPO_BRANCH}:${CFO_DIR}
    END

Run Codeflare Tests
    [Documentation]   Run codeflare-operator E2E tests from e2e directory
    [Arguments]    ${CFO_DIR}    ${CFO_TEST_RESULT_FILE}    ${TEST_TYPE}
    ${result} =    Run Process
    ...    go test -v -timeout ${GO_TEST_TIMEOUT} ./e2e -run ${TEST_TYPE} 2>&1 > ${CFO_TEST_RESULT_FILE}
    ...    shell=true    cwd=${CFO_DIR}/test
    ...    env:CODEFLARE_TEST_TIMEOUT_LONG=${CODEFLARE_TEST_TIMEOUT_LONG}
    ...    env:CLUSTER_TYPE=${CLUSTER_TYPE}
    ...    env:CLUSTERID=${CLUSTERID}
    Log To Console    ${result.stdout}
    ${test_output}=    Get File    ${CFO_TEST_RESULT_FILE}
    Log To Console    ${test_output}
    RETURN    ${result.rc}    

