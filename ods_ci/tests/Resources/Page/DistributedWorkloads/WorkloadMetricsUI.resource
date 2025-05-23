*** Settings ***
Documentation    Collection of keywords to interact with Distributed Workloads Metrics UI
Library    DateTime
Library    String
Resource         ../../Common.robot


*** Variables ***
${PROJECT_XP}=    xpath=//div[text()='Project']
${DISTRIBUITED_WORKLOAD_METRICS_TEXT_XP}=    xpath=//div[text()='Monitor the metrics of your active resources.']
${PROJECT_METRICS_TAB_XP}=    xpath=//button[@aria-label="Project metrics tab"]
${WORKLOAD_STATUS_TAB_XP}=    xpath=//button[@aria-label="Distributed workload status tab"]
${STATUS_OVERVIEW_XP}=    xpath=//div[text()='Status overview']
${REFRESH_INTERVAL_XP}=    xpath=//div[text()='Refresh interval']
${WORKLOADS_STATUS_XP}=    xpath=//div[text()='Distributed Workloads']
${REFRESH_INTERNAL_MENU_XP}=    xpath=//button[@aria-label="Options menu"]
@{STATUS_LIST}=    Pending    Inadmissible    Admitted    Running    Evicted    Succeeded    Failed
@{REFRESH_INTERNAL_LIST}=    15 seconds    30 seconds    1 minute    5 minutes    15 minutes    30 minutes    1 hour    2 hours    1 day
${DISTRIBUITED_WORKLOAD_RESOURCE_METRICS_TITLE_XP}=    xpath=//div[text()="Distributed workload resource metrics"]
${REQUESTED_RESOURCES_TITLE_XP}=    xpath=//div[text()="Requested resources"]
${RESOURCES_CONSUMING_TITLE_XP}=    xpath=//div[text()="Top 5 resource-consuming distributed workloads"]
${MAX_RETRIES}=    3
${RAY_WORKLOAD_CREATED}=    False
${KUEUE_RESOURCES_SETUP_FILEPATH}=    tests/Resources/Page/DistributedWorkloads/kueue_resources_setup.sh
${KUEUE_WORKLOADS_SETUP_FILEPATH}=    tests/Resources/Page/DistributedWorkloads/kueue_workloads.sh
${RAY_CR_FILE}=    tests/Resources/Page/DistributedWorkloads/ray_cluster_cr.yaml
${CPU_SHARED_QUOTA}=    9
${MEMEORY_SHARED_QUOTA}=    36
${tolerance}=    1
${CPU_WARNING_XP}=    //*[@id="requested-resources-chart-CPU-ChartLegend-ChartLabel-3"]
${MEMORY_WARNING_XP}=    //*[@id="requested-resources-chart-Memory-ChartLegend-ChartLabel-3"]

*** Keywords ***
Open Distributed Workload Metrics Home Page
    [Documentation]    This will launch to the distributed Workloads Home page
    Wait Until Page Contains    Distributed workloads    timeout=30
    Click Link    Distributed workloads
    Wait For RHODS Dashboard To Load    wait_for_cards=${FALSE}    expected_page=Distributed workloads

Select Distributed Workload Project By Name
    [Documentation]    Select the project in distributed workload metrics page by project name
    [Arguments]    ${project_name}
    Wait Until Element Is Visible    ${PROJECT_XP}   timeout=20
    Click Element    xpath://button[@id='project-selector']
    Click Element    xpath://button[@role="menuitem" and string()="${project_name}"]

Check Expected String Contains
    [Documentation]    Check Expected String Contains with the xpath prvoided get text
    [Arguments]    ${GET_TEXT_XP}    ${expected_output}
    ${output} =  Get Text  xpath=${GET_TEXT_XP}
    Should Contain   ${output}    ${expected_output}

Check Expected String Equals
    [Documentation]    Check Expected String Equals with the xpath prvoided get text
    [Arguments]    ${GET_TEXT_XP}    ${expected_output}
    ${output} =  Get Text  xpath=${GET_TEXT_XP}
    Should Match   ${output}    ${expected_output}

Select Refresh Interval
    [Documentation]    select refresh interval
    [Arguments]    ${refresh_interval}
    Wait Until Element Is Visible  ${REFRESH_INTERVAL_XP}    timeout=20
    Click Element     ${REFRESH_INTERNAL_MENU_XP}
    Click Element     xpath=//button[@role="option" and contains(., "${refresh_interval}")]

Get Current CPU Usage
    [Documentation]    Returns value of current cpu usage
    [Arguments]    ${namespace}    ${workload_type}
    ${thanos_url}=    Get OpenShift Thanos URL
    ${token}=    Generate Thanos Token
    ${expression}=    Set Variable
    ...    sum by(owner_name, owner_kind) (kube_pod_owner{owner_kind=~"${workload_type}", namespace="${namespace}"} * on (namespace, pod) group_right(owner_name, owner_kind) node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate)
    Wait Until Element Is Visible    xpath=//*[@id="topResourceConsumingCPU-ChartLegend-ChartLabel-0"]    timeout=60
    ${query_result}=    Prometheus.Run Query    https://${thanos_url}    ${token}    ${expression}
    IF    "${query_result.json()["data"]["result"]}" == "[]"
        FOR    ${retry}     IN RANGE    ${MAX_RETRIES}
            ${query_result}=    Prometheus.Run Query    https://${thanos_url}    ${token}    ${expression}
            Exit For Loop If    "${query_result.json()["data"]["result"]}" != "[]"
            Log    failed. Retrying...
            Wait Until Element Is Visible    xpath=//*[@id="topResourceConsumingCPU-ChartLegend-ChartLabel-0"]    timeout=60
        END
    END
    ${cpu_usage_value}=    Get Query Value    ${query_result}
    ${cpu_requested}=    Convert To Number    ${cpu_usage_value}
    ${cpu_usage_rounded_value}=    Evaluate    round( ${cpu_requested}, 3)
    RETURN  ${cpu_usage_rounded_value}

Get Current Memory Usage
    [Documentation]    Returns value of current memory usage
    [Arguments]    ${namespace}    ${workload_type}
    ${thanos_url}=    Get OpenShift Thanos URL
    ${token}=    Generate Thanos Token
    ${expression}=    Set Variable
    ...    sum by(owner_name, owner_kind) (kube_pod_owner{owner_kind=~"${workload_type}", namespace="${namespace}"} * on (namespace, pod) group_right(owner_name, owner_kind) node_namespace_pod_container:container_memory_working_set_bytes)
    Wait Until Element Is Visible    xpath=//*[@id="topResourceConsumingMemory-ChartLegend-ChartLabel-0"]     timeout=60
    ${query_result}=    Prometheus.Run Query    https://${thanos_url}    ${token}    ${expression}
    IF    "${query_result.json()["data"]["result"]}" == "[]"
        FOR    ${retry}     IN RANGE    ${MAX_RETRIES}
            ${query_result}=    Prometheus.Run Query    https://${thanos_url}    ${token}    ${expression}
            Exit For Loop If    "${query_result.json()["data"]["result"]}" != "[]"
            Log    failed. Retrying...
            Wait Until Element Is Visible    xpath=//*[@id="topResourceConsumingMemory-ChartLegend-ChartLabel-0"]     timeout=60
        END
    END
    ${memory_usage_value}=   Get Query Value    ${query_result}
    ${memory_requested}=    Convert To Number    ${memory_usage_value}
    ${memory_requested_gb_value}=    Evaluate    round( ${memory_requested} / (1024**3), 3)
    RETURN  ${memory_requested_gb_value}

Get Query Value
    [Documentation]    Returns total value of query response
    [Arguments]    ${query_response}
    @{data}=    BuiltIn.Evaluate   list(${query_response.json()["data"]["result"]})
    Log  ${data}
    ${size}=    Get Length    ${data}
    ${total}=    Set Variable    0
    IF    ${size}>1
        FOR    ${item}    IN    @{data}
            ${value}=    Get From Dictionary    ${item}    value
            ${last_value}=    Get From List    ${value}    -1
            ${total}=    Evaluate    ${total} + ${last_value}
        END
    ELSE
        ${total}=    Set Variable    ${query_response.json()["data"]["result"][0]["value"][-1]}
    END
    RETURN    ${total}

Get CPU Requested
    [Documentation]    get CPU requested from LocalQueue  flavorsReservation
    [Arguments]    ${project}    ${local_queue_name}
    ${result}  ${output}=    Run And Return Rc And Output
    ...    oc get LocalQueue ${local_queue_name} -n ${project} -o=jsonpath='{.status.flavorsReservation[0].resources[?(@.name=="cpu")].total}'
    # If CPU match millicores regex then convert value to cores, otherwise treat it as cores
    ${cpu_requested_array}=          Get Regexp Matches    ${output}      (\\d+)m      1
    ${cpu_requested_array_length}=   Get Length      ${cpu_requested_array}
    IF    ${cpu_requested_array_length} == 0
        ${cpu_requested}=    Evaluate    ${output}
    ELSE
        ${cpu_requested_millicores}=     Convert To Number    ${cpu_requested_array}[0]
        ${cpu_requested}=    Evaluate    ${cpu_requested_millicores} / 1000
    END
    RETURN   ${cpu_requested}

Get Memory Requested
    [Documentation]    get Memory requested from LocalQueue  flavorsReservation
    [Arguments]    ${project}    ${local_queue_name}    ${workload_type}
    ${result}  ${output}=    Run And Return Rc And Output
    ...    oc get LocalQueue ${local_queue_name} -n ${project} -o=jsonpath='{.status.flavorsReservation[0].resources[?(@.name=="memory")].total}'
    IF    "${workload_type}" == "Job"
        ${memory_requested}=    Replace String    ${output}    Mi    ${EMPTY}
        ${memory_requested_num}=    Convert To Number    ${memory_requested}
        ${memory_requested_gb_value}=    Evaluate    round( ${memory_requested_num} / 1024, 3)
    ELSE IF    "${workload_type}" == "RayCluster"
        ${memory_requested}=    Replace String    ${output}    Ki    ${EMPTY}
        ${memory_requested_num}=    Convert To Number    ${memory_requested}
        ${memory_requested_gb_value}=    Evaluate    round( ${memory_requested_num} / (1024*1024), 3)
    ELSE
        ${memory_requested_num}=    Convert To Number    ${output}
        ${memory_requested_gb_value}=    Evaluate    round( ${memory_requested_num} / (1024*1024*1024), 3)
    END
    RETURN  ${memory_requested_gb_value}

Get Requested Resources Tooltip Text
    [Documentation]    retuns tooltip text of requested resources chart
    Wait Until Element Is Visible    xpath://*[contains(@style, 'fill: var(--pf-v6-chart-tooltip--Fill')]
    ${tooltip_text} =  Get Text    xpath://*[contains(@style, 'fill: var(--pf-v6-chart-tooltip--Fill')]
    RETURN    ${tooltip_text}

Get Memory Requested Tooltip Text
    [Documentation]    retuns tooltip text of Memory requested chart
    Mouse Over    xpath=//*[@aria-label="Memory usage/requested"]
    Wait Until Element Is Visible    xpath://*[starts-with(@id,'pf-tooltip-')]
    ${memory_usage_hover_data} =  Get Text    xpath://*[starts-with(@id,'pf-tooltip-')]
    @{memory_usage_list}    Split To Lines    ${memory_usage_hover_data}
    ${memory_usage_line}    Set Variable    ${memory_usage_list}[0]
    ${memory_requested_line}    Set Variable    ${memory_usage_list}[1]
    ${memory_usage_value_array}=       Get Regexp Matches    ${memory_usage_line}      \\d+\\.?\\d*
    ${memory_requested_value_array}=   Get Regexp Matches    ${memory_requested_line}  \\d+\\.?\\d*
    RETURN    ${memory_usage_value_array}[0]     ${memory_requested_value_array}[0]

Get CPU Requested Tooltip Text
    [Documentation]    retuns tooltip text of CPU requested chart
    Mouse Over    xpath=//*[@aria-label="CPU usage/requested"]
    Wait Until Element Is Visible    xpath://*[starts-with(@id,'pf-tooltip-')]
    ${cpu_usage_hover_data} =  Get Text    xpath://*[starts-with(@id,'pf-tooltip-')]
    @{cpu_usage_list}    Split To Lines    ${cpu_usage_hover_data}
    ${cpu_usage_line}    Set Variable    ${cpu_usage_list}[0]
    ${cpu_requested_line}    Set Variable    ${cpu_usage_list}[1]
    ${cpu_usage_value_array}=       Get Regexp Matches    ${cpu_usage_line}      \\d+\\.?\\d*
    ${cpu_requested_value_array}=   Get Regexp Matches    ${cpu_requested_line}  \\d+\\.?\\d*
    RETURN    ${cpu_usage_value_array}[0]    ${cpu_requested_value_array}[0]

Create Ray Cluster Workload
    [Documentation]    Creates Ray cluster
    [Arguments]    ${project}    ${local_queue}    ${ray_cluster_name}
    ${rc}    ${out}=    Run And Return Rc And Output    sed -e "s/\\$NAMESPACE/${project}/g" -e "s/\\$LOCAL_QUEUE/${local_queue}/g" -e "s/\\$RAY_CLUSTER_NAME/${ray_cluster_name}/g" ${RAY_CR_FILE} | oc apply -f -
    IF    ${rc} != 0
        FAIL    Creating ray cluster workload failed
    ELSE
        Set Global Variable    ${RAY_WORKLOAD_CREATED}   True
    END

Cleanup Ray Cluster Workload
    [Documentation]    cleanup the ray cluster created workload
    [Arguments]    ${project}    ${ray_cluster_name}
    IF  ${RAY_WORKLOAD_CREATED} == True    Run    oc delete RayCluster ${ray_cluster_name} -n ${project}

Check Project Metrics Default Page Contents
    [Documentation]    checks Project Metrics Default Page contents exists
    [Arguments]    ${project_name}
    Click Button    ${PROJECT_METRICS_TAB_XP}
    Wait Until Element Is Visible    ${DISTRIBUITED_WORKLOAD_RESOURCE_METRICS_TITLE_XP}    timeout=20
    Page Should Contain Element    ${PROJECT_METRICS_TAB_XP}
    Page Should Contain Element    ${REFRESH_INTERVAL_XP}
    Page Should Contain Element    ${REQUESTED_RESOURCES_TITLE_XP}
    Check Requested Resources    ${project_name}    ${CPU_SHARED_QUOTA}    ${MEMEORY_SHARED_QUOTA}    0    0    Job
    Page Should Contain Element    ${RESOURCES_CONSUMING_TITLE_XP}
    Page Should Contain Element    xpath=//*[@data-testid="dw-top-consuming-workloads"]//*[text()="No distributed workloads in the selected project are currently consuming resources."]
    Page Should Contain Element    ${DISTRIBUITED_WORKLOAD_RESOURCE_METRICS_TITLE_XP}
    Page Should Contain Element    xpath=//*[@data-testid="dw-workload-resource-metrics"]//*[text()="No distributed workloads in the selected project are currently consuming resources."]

Check Distributed Workload Status Page Contents
    [Documentation]    checks Distributed Workload status Default Page contents exists
    Wait Until Element Is Visible  ${WORKLOADS_STATUS_XP}    timeout=20
    Page Should Contain Element    ${REFRESH_INTERVAL_XP}
    Page Should Contain Element    ${STATUS_OVERVIEW_XP}
    Page Should Contain Element    xpath=//*[@data-testid="dw-status-overview-card"]//*[text()="Select another project or create a distributed workload in the selected project."]
    Page Should Contain Element    ${WORKLOADS_STATUS_XP}
    Page Should Contain Element    xpath=//*[@data-testid="dw-workloads-table-card"]//*[text()="Select another project or create a distributed workload in the selected project."]

Setup Kueue Resources
    [Documentation]    Setup the kueue resources for the project
    [Arguments]    ${project_name}    ${cluster_queue_name}    ${resource_flavor_name}    ${local_queue_name}
    ${result} =    Run Process    sh ${KUEUE_RESOURCES_SETUP_FILEPATH} ${cluster_queue_name} ${resource_flavor_name} ${local_queue_name} ${project_name} ${CPU_SHARED_QUOTA} ${MEMEORY_SHARED_QUOTA}
    ...    shell=true
    ...    stderr=STDOUT
    Log To Console    ${result.stdout}
    IF    ${result.rc} != 0
        FAIL    Failed to setup kueue resources
    END

Cleanup Kueue Resources
    [Documentation]    Cleanup the kueue resources for the project
    [Arguments]    ${project_name}    ${cluster_queue_name}   ${resource_flavor}    ${local_queue_name}
    ${result}=    Run Process    oc delete LocalQueue ${local_queue_name} -n ${project_name} & oc delete ClusterQueue ${cluster_queue_name} & oc delete ResourceFlavor ${resource_flavor}
    ...    shell=true
    ...    stderr=STDOUT
    Log To Console    ${result.stdout}
    IF    ${result.rc} != 0
        FAIL    Failed to delete kueue resources
    END

Check Requested Resources
    [Documentation]    checks requested resource contents
    [Arguments]    ${project_name}   ${cpu_shared_quota}    ${memory_shared_quota}    ${cpu_requested}    ${memory_requested}    ${workload_type}
    Check Expected String Equals    //*[@id="requested-resources-chart-CPU-ChartLegend-ChartLabel-0"]    Requested by ${project_name}: ${cpu_requested}
    Check Expected String Equals    //*[@id="requested-resources-chart-CPU-ChartLegend-ChartLabel-2"]    Total shared quota: ${cpu_shared_quota}
    Check Expected String Equals    //*[@id="requested-resources-chart-CPU-ChartLegend-ChartLabel-1"]    Requested by all projects: ${cpu_requested}
    ${memory_requested_round} =    Evaluate    round( ${memory_requested}, 1)
    Check Expected String Equals    //*[@id="requested-resources-chart-Memory-ChartLegend-ChartLabel-0"]    Requested by ${project_name}: ${memory_requested_round}
    Check Expected String Equals    //*[@id="requested-resources-chart-Memory-ChartLegend-ChartLabel-1"]    Requested by all projects: ${memory_requested_round}
    Check Expected String Equals    //*[@id="requested-resources-chart-Memory-ChartLegend-ChartLabel-2"]   Total shared quota: ${memory_shared_quota}

Check Distributed Workload Resource Metrics Status
    [Documentation]    checks Distributed Workload Resource Metrics Status contents
    [Arguments]    ${job_name}    ${job_status}
    Check Expected String Contains    //td[@data-label="Name"]    ${job_name}
    Check Expected String Equals    //td[@data-label="Status"]//span[@class="pf-v6-c-label__text"]    ${job_status}

Compare Workload Created Date With Current Date
    [Documentation]    Check Workload Created Date To Be Less Than Equal To Current Date
    [Arguments]    ${workload_created_date}    ${current_date}
    ${check_workload_created_date}    Evaluate    datetime.datetime.strptime('${workload_created_date}','%m/%d/%Y') <= datetime.datetime.strptime('${current_date}','%m/%d/%Y')
    Should Be True    ${check_workload_created_date}    Workload created date (${workload_created_date}) should be less than or equal to the current date (${current_date}).

Check Requested Resources Chart
    [Documentation]    checks Requested Resources Chart
    [Arguments]    ${project}    ${cpu_requested}   ${memory_requested}
    Mouse Over    xpath=(//*[name()='svg']//*[local-name()='g']//*[local-name()='path'])[2]
    ${hover_cpu_requested} =  Get Requested Resources Tooltip Text
    Should Match   ${hover_cpu_requested}   Requested by ${project}: ${cpu_requested} cores
    Mouse Over    xpath=//*[@id="requested-resources-chart-CPU-ChartLegend-ChartLabel-0"]

    Mouse Over    xpath=(//*[name()='svg']//*[local-name()='g']//*[local-name()='path'])[8]
    ${hover_memory_requested} =    Get Requested Resources Tooltip Text
    Should Match   ${hover_memory_requested}   Requested by ${project}: ${memory_requested} GiB

    Mouse Over    xpath=//*[@id="requested-resources-chart-CPU-ChartLegend-ChartLabel-0"]

    Mouse Over    xpath=(//*[name()='svg']//*[local-name()='g']//*[local-name()='path'])[1]
    ${hover_cpu_shared_quota} =    Get Requested Resources Tooltip Text
    Should Match   ${hover_cpu_shared_quota}   Total shared quota: ${CPU_SHARED_QUOTA} cores

    Mouse Over    xpath=//*[@id="requested-resources-chart-CPU-ChartLegend-ChartLabel-0"]

    Mouse Over    xpath=(//*[name()='svg']//*[local-name()='g']//*[local-name()='path'])[7]
    ${hover_memory_shared_quota} =    Get Requested Resources Tooltip Text
    Should Match   ${hover_memory_shared_quota}   Total shared quota: ${MEMEORY_SHARED_QUOTA} GiB

Check Distributed Workload Resource Metrics Chart
    [Documentation]    checks Distributed Workload Resource Metrics Chart
    [Arguments]    ${project}    ${cpu_requested}   ${memory_requested}    ${workload_type}    ${job_name}

    Wait Until Element Is Visible    xpath=//*[@id="topResourceConsumingCPU-ChartLabel-title"]    timeout=120
    Wait Until Element Is Visible    xpath=//*[@id="topResourceConsumingCPU-ChartLegend-ChartLabel-0"]   timeout=120
    Check Expected String Contains    //*[@id="topResourceConsumingCPU-ChartLegend-ChartLabel-0"]    ${job_name}

    ${cpu_usage} =    Get Current CPU Usage    ${project}    ${workload_type}
    ${cpu_usage_hover_value}     ${cpu_requested_hover_value} =  Get CPU Requested Tooltip Text
    Check Resource Consuming Usage    ${cpu_usage}    ${cpu_usage_hover_value}    CPU
    Should Be True     ${cpu_requested_hover_value} == ${cpu_requested}
    ${cpu_consuming} =    Get Text    xpath:(//*[@style[contains(., 'var(--pf-v6-chart-donut--label--title--Fill')]])[1]
    Check Resource Consuming Usage    ${cpu_usage}    ${cpu_consuming}    CPU

    Mouse Over    (//button[@class="pf-v6-c-table__button"])[1]

    Wait Until Element Is Visible    xpath=//*[@id="topResourceConsumingMemory-ChartLabel-title"]    timeout=120
    Wait Until Element Is Visible    xpath=//*[@id="topResourceConsumingMemory-ChartLegend-ChartLabel-0"]    timeout=120
    Check Expected String Contains    //*[@id="topResourceConsumingMemory-ChartLegend-ChartLabel-0"]    ${job_name}

    ${memory_usage}=   Get Current Memory Usage    ${project}    ${workload_type}
    ${memory_usage_hover_value}     ${memory_requested_hover_value} =  Get Memory Requested Tooltip Text
    Check Resource Consuming Usage    ${memory_usage}    ${memory_usage_hover_value}    Memory
    Should Be True     ${memory_requested_hover_value} == ${memory_requested}
    ${memory_consuming} =    Get Text    xpath:(//*[@style[contains(., 'var(--pf-v6-chart-donut--label--title--Fill')]])[2]
    Check Resource Consuming Usage    ${memory_usage}    ${memory_consuming}    Memory

Check Distributed Worklaod Status Overview
    [Documentation]    checks Distributed Worklaod Status Overview displaying correctly
    [Arguments]    ${job_name}    ${job_status}    ${job_status_message}
    Click Button    ${WORKLOAD_STATUS_TAB_XP}
    Wait Until Element Is Visible    xpath=//div[text()="Distributed Workloads"]    timeout=20
    Check Expected String Equals    //*[@id="status-overview-ChartLabel-title"]    1Distributed Workloads
    Page Should Contain    text=${JOB_STATUS}: 1
    Check Expected String Contains    //td[@data-label="Name"]    ${job_name}
    Check Expected String Equals    //td[@data-label="Priority"]    0
    ${get_current_date} =    Get Current Date    result_format=%-m/%-d/%Y
    ${get_created_datetime} =    Get Text    xpath=//td[@data-label="Created"]
    ${get_created_date} =    Evaluate    re.search(r'[^,]+','''${get_created_datetime}''').group(0)
    Compare Workload Created Date With Current Date    ${get_created_date}    ${get_current_date}
    Check Expected String Equals    //td[@data-label="Status"]//span[@class="pf-v6-c-label__text"]    ${job_status}
    Check Expected String Equals    //td[@data-label="Latest Message"]    ${job_status_message}

Check Resource Consuming Usage
    [Documentation]    assert the resource consuming usage
    [Arguments]    ${usage_expected}   ${usage_hover}    ${resource_name}
    ${usage_lower_bound} =    Evaluate    ${usage_expected} - ${tolerance}
    ${usage_higher_bound} =    Evaluate    ${usage_expected} + ${tolerance}
    Run Keyword If    ${usage_hover} == ${usage_expected}
    ...    Log    ${resource_name} Usage value is accurate
    ...    ELSE IF    ${usage_hover} > ${usage_lower_bound} and ${usage_hover} < ${usage_higher_bound}
    ...    Log    ${resource_name} usage value is partially matches
    ...    ELSE    Fail    ${resource_name} usage hover value ${usage_hover} is not matching with expected value ${usage_expected}

Submit Kueue Workload
    [Documentation]    method for creating kueue workload
    [Arguments]    ${local_queue}   ${project}    ${cpu_requested}    ${memory_requested}    ${job_name_queue}    ${add_annotation}=${False}    ${parallelism}=None
    ${result}=    Run Process    sh ${KUEUE_WORKLOADS_SETUP_FILEPATH} ${local_queue} ${project} ${cpu_requested} ${memory_requested} ${job_name_queue} ${add_annotation} ${parallelism}
    ...    shell=true
    ...    stderr=STDOUT
    Log To Console    ${result.stdout}
    IF    ${result.rc} != 0
        FAIL    Failed to submit kueue workloads
    END

Wait For Job With Status
    [Documentation]    Wait for job status with job name
    [Arguments]    ${job_name}    ${job_status}    ${timeout}
    Wait Until Element Is Visible    //td[@class='pf-v6-c-table__td' and contains(text(), '${job_name}')]/following-sibling::td[@data-label='Status']/span/span/span[@class='pf-v6-c-label__text'and text()='${job_status}']    timeout=${timeout}

Check Warning Threshold Chart
    [Documentation]    verifies warning threshold of cpu and memory resources
    Mouse Over    xpath=(//*[name()='svg']//*[local-name()='g']//*[local-name()='path'])[4]
    ${hover_cpu_warning} =  Get Requested Resources Tooltip Text
    Should Match   ${hover_cpu_warning}   Requested resources have surpassed 150%
    Mouse Over    xpath=//*[@id="requested-resources-chart-CPU-ChartLegend-ChartLabel-0"]

    Mouse Over    xpath=(//*[name()='svg']//*[local-name()='g']//*[local-name()='path'])[12]
    ${hover_memory_warning} =  Get Requested Resources Tooltip Text
    Should Match   ${hover_memory_warning}   Requested resources have surpassed 150%
    Mouse Over    xpath=//*[@id="requested-resources-chart-Memory-ChartLegend-ChartLabel-0"]
