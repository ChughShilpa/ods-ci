*** Settings ***
Documentation    This is a resource file for CodeflareOperator
Library          OperatingSystem
Library          Process

*** Variables ***
${CODEFLARE_DIR}            codeflare-operator
${CODEFLARE_REPO_URL}       %{CODEFLARE_REPO_URL=https://github.com/opendatahub-io/codeflare-operator.git}
${CODEFLARE_REPO_BRANCH}    %{CODEFLARE_REPO_BRANCH=main}


*** Keywords ***
Prepare Codeflare E2E Test Suite
    ${result} =    Run Process    git clone -b ${CODEFLARE_REPO_BRANCH} ${CODEFLARE_REPO_URL} ${CODEFLARE_DIR}
    ...    shell=true    stderr=STDOUT
    Log To Console    ${result.stdout}
    IF    ${result.rc} != 0
        FAIL    Unable to clone Codeflare repo ${CODEFLARE_REPO_URL}:${CODEFLARE_REPO_BRANCH}
    END
    
    ${result} =    Run Process    oc patch datascienceclusters.datasciencecluster.opendatahub.io rhods --type 'json' -p '[{"op" : "replace" ,"path" : "/spec/components/ray/managementState" ,"value" : "Managed"}]'
    ...    shell=true    stderr=STDOUT
    IF    ${result.rc} != 0
        FAIL    Can not enable ray
    END
    ${result} =    Run Process    oc patch datascienceclusters.datasciencecluster.opendatahub.io rhods --type 'json' -p '[{"op" : "replace" ,"path" : "/spec/components/codeflare/managementState" ,"value" : "Managed"}]'
    ...    shell=true    stderr=STDOUT
    IF    ${result.rc} != 0
        FAIL    Can not enable codeflare
    END
 #   Create Directory    Logs/codeflare-logs
     Create Directory    %{WORKSPACE}/codeflare-logs

Run Codeflare E2E Test
    [Arguments]    ${TEST_NAME}    ${CLUSTER_ID}
    Log To Console    "Running test: ${TEST_NAME}"
    ${result} =    Run Process    go test -timeout 30m -v ./test/e2e -run ${TEST_NAME}
    ...    shell=true
    ...    stderr=STDOUT
    ...    cwd=${CODEFLARE_DIR}
    ...    env:CODEFLARE_TEST_TIMEOUT_LONG=30m
    ...    env:CODEFLARE_TEST_OUTPUT_DIR=%{WORKSPACE}/codeflare-logs
#    ...    env:CODEFLARE_TEST_OUTPUT_DIR=Logs/codeflare-logs
    ...    env:CLUSTER_TYPE=OSD
    ...    env:CLUSTERID=${CLUSTER_ID}
    Log To Console    ${result.stdout}
    IF    ${result.rc} != 0
        FAIL    ${TEST_NAME} failed
    END

Create Instascale Secret
    [Arguments]    ${TOKEN}
    Log To Console    "Creating secret ....."
    Run    oc create secret generic instascale-ocm-secret -n default --from-literal=token=${TOKEN}