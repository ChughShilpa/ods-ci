*** Settings ***
Library           OpenShiftLibrary
Resource         ../../Resources/Page/CodeflareOperator/CodeflareOperator.resource
Resource         ../../Resources/Common.robot
Library          ../../../utils/scripts/ocm/ocm.py

*** Variables ***
 
*** Test Cases ***
Run TestInstascaleMachinePool test
    [Documentation]    Run Go E2E test TestInstascaleMachinePool
    ...                This particular test runs on OSD cluster
    
    [Tags]  CodeflareOperator

    CodeflareOperator.Prepare Codeflare E2E Test Suite

    # Set instascale  to true in the codeflare operator config map
    Log To Console    "Setting instascale to true in config map ....."

    Run Process    oc get cm codeflare-operator-config -n redhat-ods-applications -o yaml | sed -e 's|enabled: false|enabled: true|' | oc apply -f -

    # Fetch CLUSTERID and pass it as test env
    Log To Console    "Fetching cluster_id test ......."
    ${cluster_id} = ocm.get_osd_cluster_id    {1}
    Log To Console    "Cluster_id = ${cluster_id}"
    Log To Console    "${cluster_id}"

    # Run TestInstascaleMachinePool test
    Log To Console    "Running instascale test ......."
    Run Codeflare E2E Test    TestInstascaleMachinePool    ${cluster_id}
