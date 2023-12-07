*** Settings ***
Library           OpenShiftLibrary
Resource         ../../Resources/Page/CodeflareOperator/CodeflareOperator.resource
Resource         ../../Resources/Common.robot
Library          ../../../utils/scripts/ocm/ocm.py

*** Variables ***
${token}
 
*** Test Cases ***
Run TestInstascaleMachinePool test
    [Documentation]    Run Go E2E test TestInstascaleMachinePool
    ...                This particular test runs on OSD cluster
    
    [Tags]  CodeflareOperator

    # CodeflareOperator.Prepare Codeflare E2E Test Suite

    # Set instascale  to true in the codeflare operator config map
    Log To Console    "Setting instascale to true in config map ....."
    ${result} =    Run Process    oc get cm codeflare-operator-config -n redhat-ods-applications -o yaml | sed -e 's|enabled: false|enabled: true|' | oc apply -f -
    ...    shell=true    stderr=STDOUT
    IF    ${result.rc} != 0
        FAIL    Can not enable instascale to true
    END

    # Generate ocm token and create a secret
    Log To Console    "Generating token ....."
    ${token} =    Run Process    ocm token --generate
    ...    shell=true    stderr=STDOUT
    IF    ${token.rc} != 0
        FAIL    Can not generate token
    END
    CodeflareOperator.Create Instascale Secret    ${token.stdout}

    #Fetch cluster ID
    Log To Console    "Fetching cluster details ....."
    # ${cluster_id} = Run Process    ocm list clusters | grep %{TEST_CLUSTER} | awk '{print $1}'
    ${cluster_id} =    Run Process    ocm list clusters | grep %{TEST_CLUSTER} | awk '{print $1}'
    ...    shell=true    stderr=STDOUT
    Log To Console    "Value of cluster_id   ............"
    Log To Console    ${cluster_id.stdout}
    IF    ${cluster_id.rc} != 0
        FAIL    Can not fetch cluster details
    END

    # Run TestInstascaleMachinePool test
    Log To Console    "Running instascale test ......."
    Run Codeflare E2E Test    TestInstascaleMachinePool    ${cluster_id.stdout}