*** Settings ***
Library   SeleniumLibrary
Library   JupyterLibrary
Library   OperatingSystem
Library   DependencyLibrary
Library   Process
Library   RequestsLibrary
Library   ../../libs/Helpers.py
Resource  OCP.resource
Resource  Page/ODH/JupyterHub/JupyterLabLauncher.robot
Resource  Page/ODH/JupyterHub/JupyterHubSpawner.robot
Resource  ../../tasks/Resources/RHODS_OLM/install/oc_install.robot
Resource  RHOSi.resource


*** Variables ***
@{DEFAULT_CHARS_TO_ESCAPE}=    :    /    .
${UWM_CONFIG_FILEPATH}=       tests/Resources/Files/uwm_cm_conf.yaml
${UWM_ENABLE_FILEPATH}=       tests/Resources/Files/uwm_cm_enable.yaml


*** Keywords ***
Begin Web Test
    [Documentation]  This keyword should be used as a Suite Setup; it will log in to the
    ...              ODH dashboard, checking that the spawner is in a ready state before
    ...              handing control over to the test suites.
    [Arguments]    ${username}=${TEST_USER.USERNAME}    ${password}=${TEST_USER.PASSWORD}
    ...            ${auth_type}=${TEST_USER.AUTH_TYPE}    ${jupyter_login}=${TRUE}
    Set Library Search Order  SeleniumLibrary
    RHOSi Setup
    Open Browser  ${ODH_DASHBOARD_URL}  browser=${BROWSER.NAME}  options=${BROWSER.OPTIONS}
    Login To RHODS Dashboard  ${username}  ${password}  ${auth_type}
    Wait For RHODS Dashboard To Load
    IF    ${jupyter_login}
        Launch Jupyter From RHODS Dashboard Link
        Login To Jupyterhub  ${username}  ${password}  ${auth_type}
        Verify Service Account Authorization Not Required
        Fix Spawner Status
        Go To  ${ODH_DASHBOARD_URL}
    END

End Web Test
    [Arguments]    ${username}=${TEST_USER.USERNAME}
    ${server}=    Run Keyword And Return Status    Page Should Contain Element
    ...    //div[@id='jp-top-panel']//div[contains(@class, '-MenuBar-itemLabel')][text() = 'File']
    IF  ${server}==True
        Clean Up Server    username=${username}
        Stop JupyterLab Notebook Server
        Capture Page Screenshot
    END
    Close Browser

End Non JupyterLab Web Test
    [Documentation]  Stops running workbench that was started by logged-in user via the
    ...              JupyterHub launcher space.
    Go To  ${ODH_DASHBOARD_URL}
    Wait For RHODS Dashboard To Load
    Launch Jupyter From RHODS Dashboard Link
    Handle Control Panel
    Capture Page Screenshot
    Close Browser

Load Json File
    [Arguments]   ${file_path}      ${as_string}=${FALSE}
    ${j_file}=    Get File    ${file_path}
    ${obj}=    Evaluate    json.loads(r'''${j_file}''')    json
    IF  ${as_string}
       ${obj}=    Evaluate    json.dumps(${obj})    json
    END
    RETURN    ${obj}


Load Json String
    [Arguments]     ${json_string}
    ${obj}=     Evaluate  json.loads(r"""${json_string}""")
    RETURN    ${obj}

Create File From Template
    [Documentation]     Create new file from a template file, by replacing environment variables values
    [Arguments]   ${template_file}    ${output_file}
    ${template_data} = 	Get File 	${template_file}
    ${output_data} = 	Replace Variables 	${template_data}
    Create File  ${output_file}  ${output_data}

Export Variables From File
    [Documentation]     Export variables from file with lines format of: variable=value
    [Arguments]   ${variables_file}
    ${file_data} = 	Get File 	${variables_file}
    @{list} =    Split to lines  ${file_data}
    FOR    ${line}     IN    @{list}
        Log     ${line}
        ${line} =    Remove String    ${line}    export
        ${var_and_value} =    Split String    string=${line}    separator==
        Set Suite Variable    ${${var_and_value}[0]}    ${var_and_value}[1]
    END

Get CSS Property Value
    [Documentation]    Get the CSS property value of a given element
    [Arguments]    ${locator}    ${property_name}
    ${element}=       Get WebElement    ${locator}
    ${css_prop}=    Call Method       ${element}    value_of_css_property    ${property_name}
    RETURN     ${css_prop}

CSS Property Value Should Be
    [Documentation]     Compare the actual CSS property value with the expected one
    [Arguments]   ${locator}    ${property}    ${exp_value}   ${operation}=equal
    ${el_text}=   Get Text   xpath:${locator}
    Log    Text of the target element: ${el_text}
    ${actual_value}=    Get CSS Property Value   xpath:${locator}    ${property}
    IF    $operation == "contains"
        Run Keyword And Continue On Failure   Should Contain    ${actual_value}    ${exp_value}
    ELSE
        Run Keyword And Continue On Failure   Should Be Equal    ${actual_value}    ${exp_value}
    END

Get All Text Under Element
    [Documentation]    Returns a list of all text content under an element tree, including trailing spaces
    # This is usefull since Get Text ignores trailing spaces and sibling elements.
    # The returned list can be evaluated with keyword:    Should Contain    ${text_list}    Text Data
    [Arguments]   ${parent_element}
    ${elements}=    Get WebElements    ${parent_element}
    ${text_list}=    Create List
    FOR    ${element}    IN    @{elements}
        ${status}    ${text}=    Run Keyword And Ignore Error
        ...    Get Element Attribute    ${element}    textContent
        Run Keyword If    '${status}' == 'PASS'    Append To List    ${text_list}    ${text}
    END
    RETURN   ${text_list}

Scroll And Input Text Into Element
    [Documentation]    Scrolls element into view and inputs text into the element
    [Arguments]    ${element}    ${text}
    Scroll Element Into View    ${element}
    ${text_entered}=    Run Keyword And Return Status    Input Text    ${element}    ${text}
    IF    ${text_entered}    RETURN
    Click Element    ${element}
    Press Keys    NONE    ${text}

Get All Strings That Contain
    [Documentation]    Returns new list of strings, for each item in ${list_of_strings} that contains ${substring_to_search}
    [Arguments]   ${list_of_strings}    ${substring_to_search}
    ${matched_list}=    Create List
    FOR    ${str}    IN    @{list_of_strings}
        IF    "${substring_to_search}" in "${str}"    Append To List    ${matched_list}    ${str}
    END
    RETURN   ${matched_list}

Lists Size Should Be Equal
    [Documentation]  Verifies two lists have same number of items
    [Arguments]   ${list_one}    ${list_two}
    ${length_one}=  Get Length  ${list_one}
    ${length_two}=  Get Length  ${list_two}
    Should Be Equal As Integers  ${length_one}  ${length_two}

Page Should Contain A String In List
    [Documentation]    Verifies that page contains at least one of the strings in text_list
    [Arguments]  ${text_list}
    FOR    ${text}    IN    @{text_list}
        ${text_found}=    Run Keyword And Return Status    Page Should Contain   ${text}
        IF  ${text_found}    RETURN
    END
    Fail    Current page doesn't contain any of the strings in: @{text_list}

Wait Until Page Contains A String In List
    [Documentation]    Waits until page contains at least one of the strings in text_list
    [Arguments]    ${text_list}    ${retry}=12x    ${retry_interval}=5s
    Wait Until Keyword Succeeds    ${retry}   ${retry_interval}
    ...    Page Should Contain A String In List     ${text_list}

#robocop: disable: line-too-long
Get RHODS Version
    [Documentation]    Return RHODS/ODH operator version number.
    ...    Will fetch version only if $RHODS_VERSION was not already set, or $force_fetch is True.
    [Arguments]    ${force_fetch}=False
    IF  "${RHODS_VERSION}" == "${None}" or "${force_fetch}"=="True"
        IF  "${PRODUCT}" == "${None}" or "${PRODUCT}" == "RHODS"
            ${RHODS_VERSION}=  Run  oc get csv -n ${OPERATOR_NAMESPACE} | grep "rhods-operator" | awk -F ' {2,}' '{print $3}'
        ELSE
            ${RHODS_VERSION}=  Run  oc get csv -n ${OPERATOR_NAMESPACE} | grep "opendatahub" | awk -F ' {2,}' '{print $3}'
        END
    END
    Log  Product:${PRODUCT} Version:${RHODS_VERSION}
    RETURN  ${RHODS_VERSION}

#robocop: disable: line-too-long
Get CodeFlare Version
    [Documentation]    Return RHODS CodeFlare operator version number.
    ...    Will fetch version only if $CODEFLARE_VERSION was not already set, or $force_fetch is True.
    [Arguments]    ${force_fetch}=False
    IF  "${CODEFLARE_VERSION}" == "${None}" or "${force_fetch}" == "True"
        IF  "${PRODUCT}" == "${None}" or "${PRODUCT}" == "RHODS"
            ${CODEFLARE_VERSION}=  Run  oc get csv -n openshift-operators | grep "rhods-codeflare-operator" | awk '{print $1}' | sed 's/rhods-codeflare-operator.//'
        ELSE
            ${CODEFLARE_VERSION}=  Run  oc get csv -n openshift-operators | grep "codeflare-operator" | awk -F ' {2,}' '{print $3}'
        END
    END
    Log  Product:${PRODUCT} CodeFlare Version:${CODEFLARE_VERSION}
    RETURN  ${CODEFLARE_VERSION}

#robocop: disable: line-too-long
Wait Until Csv Is Ready
  [Documentation]   Waits ${timeout} for Operators CSV '${display_name}' to have status phase 'Succeeded'
  [Arguments]    ${display_name}    ${timeout}=10m    ${operators_namespace}=openshift-operators
  Log    Waiting ${timeout} for Operator CSV '${display_name}' in ${operators_namespace} to have status phase 'Succeeded'    console=yes
  WHILE   True    limit=${timeout}
  ...    on_limit_message=${timeout} Timeout exceeded waiting for CSV '${display_name}' to be created
    ${csv_created}=    Run Process    oc get csv --no-headers -n ${operators_namespace} | awk '/${display_name}/ {print \$1}'    shell=yes
    IF    "${csv_created.stdout}" == "${EMPTY}"    CONTINUE
    ${csv_ready}=    Run Process
    ...    oc wait --timeout\=${timeout} --for jsonpath\='{.status.phase}'\=Succeeded csv -n ${operators_namespace} ${csv_created.stdout}    shell=yes
    IF    ${csv_ready.rc} == ${0}    BREAK
  END

Get Cluster ID
    [Documentation]     Retrieves the ID of the currently connected cluster
    ${cluster_id}=   Run    oc get clusterversion -o json | jq .items[].spec.clusterID
    IF    not $cluster_id
        Fail    Unable to retrieve cluster ID. Are you logged using `oc login` command?
    END
    ${cluster_id}=    Remove String    ${cluster_id}    "
    RETURN    ${cluster_id}

Get Cluster Name By Cluster ID
    [Documentation]     Retrieves the name of the currently connected cluster given its ID
    [Arguments]     ${cluster_id}
    ${cluster_name}=    Get Cluster Name     cluster_identifier=${cluster_id}
    IF    not $cluster_name
        Fail    Unable to retrieve cluster name for cluster ID ${cluster_id}
    END
    RETURN    ${cluster_name}

Wait Until HTTP Status Code Is
    [Documentation]     Waits Until Status Code Of URl Matches expected Status Code
    [Arguments]  ${url}   ${expected_status_code}=200  ${retry}=1m   ${retry_interval}=15s
    Wait Until Keyword Succeeds    ${retry}   ${retry_interval}
    ...    Check HTTP Status Code    ${url}    ${expected_status_code}

Check HTTP Status Code
    [Documentation]     Verifies Status Code of URL Matches Expected Status Code
    [Arguments]  ${link_to_check}    ${expected}=200    ${timeout}=20   ${verify_ssl}=${True}    ${allow_redirects}=${True}
    ${headers}=    Create Dictionary    User-Agent="Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
    ${response}=    RequestsLibrary.GET  ${link_to_check}   expected_status=any   headers=${headers}
    ...    timeout=${timeout}  verify=${verify_ssl}    allow_redirects=${allow_redirects}
    ${status_verified}=    Run Keyword And Return Status    Status Should Be    ${expected}    ${response}
    IF    not ${status_verified}
        Log    URL '${link_to_check}' returned '${response.status_code}' - Retrying with empty Headers    console=True
        ${response}=    RequestsLibrary.GET  ${link_to_check}   expected_status=any
        ...    timeout=${timeout}  verify=${verify_ssl}    allow_redirects=${allow_redirects}
        Run Keyword And Continue On Failure    Status Should Be    ${expected}    ${response}
    END
    RETURN  ${response.status_code}

URLs HTTP Status Code Should Be Equal To
    [Documentation]    Given a list of link web elements, extracts the URLs and
    ...                checks if the http status code expected one is equal to the
    [Arguments]    ${link_elements}    ${expected_status}=200    ${timeout}=20
    Should Not Be Empty    ${link_elements}    msg=The list of URLs to validate is empty (Maybe an invalid Xpath caused it).
    FOR    ${idx}    ${ext_link}    IN ENUMERATE    @{link_elements}    start=1
        ${href}=    Get Element Attribute    ${ext_link}    href
        ${text}=    Get Text    ${ext_link}
        ${status}=    Run Keyword And Continue On Failure    Check HTTP Status Code    link_to_check=${href}
        ...                                                                            expected=${expected_status}
        Log To Console    ${idx}. ${href} gets status code ${status}
    END

Get List Of Atrributes
    [Documentation]    Returns the list of attributes
    [Arguments]    ${xpath}    ${attribute}
    ${xpath} =    Remove String    ${xpath}    ]
    ${link_elements}=
    ...    Get WebElements    ${xpath} and not(starts-with(@${attribute}, '#'))]
    ${list_of_atrributes}=    Create List
    FOR    ${ext_link}    IN    @{link_elements}
        ${ids}=    Get Element Attribute    ${ext_link}    ${attribute}
        Append To List    ${list_of_atrributes}    ${ids}
    END
    RETURN    ${list_of_atrributes}

Verify NPM Version
    [Documentation]  Verifies the installed version of an NPM library
    ...    against an expected version in a given pod/container
    [Arguments]  ${library}  ${expected_version}  ${pod}  ${namespace}  ${container}=""  ${prefix}=""  ${depth}=0
    ${installed_version} =  Run  oc exec -n ${namespace} ${pod} -c ${container} -- npm list --prefix ${prefix} --depth=${depth} | awk -F@ '/${library}/ { print $2}'
    Should Be Equal  ${installed_version}  ${expected_version}

Get Cluster Name From Console URL
    [Documentation]    Get the cluster name from the Openshift console URL
    ${name}=    Split String    ${OCP_CONSOLE_URL}        .
    RETURN    ${name}[2]

Clean Resource YAML Before Creating It
    [Documentation]    Removes from a yaml of an Openshift resource the metadata which prevent
    ...                the yaml to be applied after being copied
    [Arguments]    ${yaml_data}
    ${clean_yaml_data}=     Copy Dictionary    dictionary=${yaml_data}  deepcopy=True
    Remove From Dictionary    ${clean_yaml_data}[metadata]  managedFields  resourceVersion  uid  creationTimestamp  annotations
    RETURN   ${clean_yaml_data}

Skip If RHODS Version Greater Or Equal Than
    [Documentation]    Skips test if RHODS version is greater or equal than ${version}
    [Arguments]    ${version}    ${msg}=${EMPTY}

    ${version-check}=  Is RHODS Version Greater Or Equal Than  ${version}

    IF    "${msg}" != "${EMPTY}"
       Skip If    condition=${version-check}==True    msg=${msg}
    ELSE
       Skip If    condition=${version-check}==True    msg=This test is skipped for RHODS ${version} or greater
    END

Skip If RHODS Is Self-Managed
    [Documentation]    Skips test if RHODS is installed as Self-managed or PRODUCT=ODH
    [Arguments]    ${msg}=${EMPTY}
    ${is_self_managed}=    Is RHODS Self-Managed
    IF    "${msg}" != "${EMPTY}"
       Skip If    condition=${is_self_managed}==True    msg=${msg}
    ELSE
       Skip If    condition=${is_self_managed}==True    msg=This test is skipped for Self-managed RHODS
    END

Skip If RHODS Is Managed
    [Documentation]    Skips test if RHODS is installed as Self-managed
    [Arguments]    ${msg}=${EMPTY}
    ${is_self_managed}=    Is RHODS Self-Managed
    IF    "${msg}" != "${EMPTY}"
       Skip If    condition=${is_self_managed}==False    msg=${msg}
    ELSE
       Skip If    condition=${is_self_managed}==False    msg=This test is skipped for Managed RHODS
    END

Skip If Namespace Does Not Exist
    [Documentation]    Skips test if ${namespace} does not exist in the cluster
    [Arguments]    ${namespace}    ${msg}=${EMPTY}
    ${rc}=    Run And Return Rc    oc get project ${namespace}
    IF    "${msg}" != "${EMPTY}"
       Skip If    condition="${rc}"!="${0}"    msg=${msg}
    ELSE
       Skip If    condition="${rc}"!="${0}"    msg=This test is skipped because namespace ${namespace} does not exist
    END

Skip If Test Enviroment Is ROSA-HCP
    [Documentation]    Skips test if test environment is ROSA_HCP
    [Arguments]    ${msg}=${EMPTY}
    ${is_rosa_hcp}=    Is Test Enviroment ROSA-HCP
    IF    "${msg}" != "${EMPTY}"
       Skip If    condition=${is_rosa_hcp}==${TRUE}    msg=${msg}
    ELSE
       Skip If    condition=${is_rosa_hcp}==${TRUE}    msg=This test is skipped for ROSA-HCP clusters
    END

Run Keyword If RHODS Is Managed
    [Documentation]    Runs keyword ${name} using  @{arguments} if RHODS is Managed (Cloud Version)
    [Arguments]    ${name}    @{arguments}
    ${is_self_managed}=    Is RHODS Self-Managed
    IF    ${is_self_managed} == False    Run Keyword    ${name}    @{arguments}

Run Keyword If RHODS Is Self-Managed
    [Documentation]    Runs keyword ${name} using  @{arguments}
    ...    if RHODS is Self-Managed or PRODUCT=ODH
    [Arguments]    ${name}    @{arguments}
    ${is_self_managed}=    Is RHODS Self-Managed
    IF    ${is_self_managed} == True    Run Keyword    ${name}    @{arguments}

Get Sub Domain Of Current URL
    [Documentation]    Gets the sub-domain of the current URL (i.e. everything before the first dot in the URL)
    ...    e.g. https://console-openshift-console.apps.<cluster>.rhods.ccitredhat.com -> https://console-openshift-console
    ...    e.g. https://rhods-dashboard-redhat-ods-applications.apps.<cluster>.rhods.ccitredhat.com/ -> https://rhods-dashboard-redhat-ods-applications
    ${current_url} =    Get Location
    ${domain} =    Fetch From Left    string=${current_url}    marker=.
    RETURN    ${domain}

Does Current Sub Domain Start With
    [Documentation]    Check if current sub-domain start with the given String
    ...   and returns True/False
    [Arguments]    ${url}
    ${subdomain} =    Get Sub Domain Of Current URL
    ${comparison} =    Run Keyword And Return Status    Should Start With
    ...    ${subdomain}    ${url}
    RETURN    ${comparison}

Get OAuth Cookie
    [Documentation]     Fetches the "_oauth_proxy" cookie from Dashboard page.
    ...                 You can use the value from this cookie to perform login in API calls.
    ...                 It assumes Dashboard UI has been launched and login performed using UI.
    ${cookie}=     Get Cookie  _oauth_proxy
    RETURN    ${cookie.value}

Retry To Click Element
    [Documentation]    Try to click an element up to a specified timeout
    [Arguments]    ${locator}    ${timeout}=10s    ${interval}=1s
    Wait Until Keyword Succeeds    ${timeout}    ${interval}    Click Element    ${locator}

Is Generic Modal Displayed
    [Documentation]    Checks if a modal window is displayed on the page.
    ...                It assumes the html "id" contains "pf-modal-", but it can be
    ...                piloted with ${id} and ${partial_match} arguments
    [Arguments]     ${id}=pf-modal-  ${partial_match}=${TRUE}  ${timeout}=10s
    IF    ${partial_match} == ${TRUE}
        ${is_displayed}=    Run Keyword And Return Status
        ...                 Page Should Contain Element    xpath=//*[contains(@id,"${id}")]
    ELSE
        ${is_displayed}=    Run Keyword And Return Status
        ...                 Page Should Contain Element    xpath=//*[@id="${id}")]
    END
    RETURN    ${is_displayed}

Wait Until Generic Modal Disappears
    [Documentation]    Waits until a modal window disappears from the page.
    ...                It assumes the html "id" contains "pf-modal-", but it can be
    ...                piloted with ${id} and ${partial_match} arguments
    [Arguments]     ${id}=pf-modal-  ${partial_match}=${TRUE}  ${timeout}=10s
    ${is_modal}=    Is Generic Modal Displayed
    IF    ${is_modal} == ${TRUE}
        IF    ${partial_match} == ${TRUE}
            ${is_displayed}=    Run Keyword And Return Status    xpath=//*[contains(@id,"${id}")]    timeout=${timeout}
            IF    ${is_displayed}
                Wait Until Page Does Not Contain Element    xpath=//*[contains(@id,"${id}")]    timeout=${timeout}
            END
        ELSE
            Wait Until Page Does Not Contain Element    xpath=//*[@id="${id}")]    timeout=${timeout}
        END
    ELSE
        Log     No Modals on the screen right now..     level=WARN
    END

Wait Until Generic Modal Appears
    [Documentation]    Waits until a modal window appears on the page.
    ...                It assumes the html "id" contains "pf-modal-", but it can be
    ...                piloted with ${id} and ${partial_match} arguments
    [Arguments]     ${id}=pf-modal-  ${partial_match}=${TRUE}  ${timeout}=10s
    ${is_modal}=    Is Generic Modal Displayed
    IF    ${is_modal} == ${FALSE}
        IF    ${partial_match} == ${TRUE}
            Wait Until Page Contains Element    xpath=//*[contains(@id,"${id}")]    timeout=${timeout}
        ELSE
            Wait Until Page Contains Element    xpath=//*[@id="${id}")]    timeout=${timeout}
        END
    ELSE
        Log     No Modals on the screen right now..     level=WARN
    END

Close Generic Modal If Present
    [Documentation]    Close a modal window from the page and waits for it to disappear
    ${is_modal}=    Is Generic Modal Displayed
    IF    ${is_modal} == ${TRUE}
        Click Element    xpath=//button[@aria-label="Close"]
        Wait Until Generic Modal Disappears
    END

Extract Value From JSON Path
    [Documentation]    Given a Python JSON Object (i.e., a dictionary) and
    ...                a desired path (e.g., spec.resources.limits.cpu), it retrieves
    ...                the value by looping into the dictionary.
    [Arguments]    ${json_dict}    ${path}
    ${path_splits}=    Split String    string=${path}    separator=.
    ${value}=    Set Variable    ${json_dict}
    FOR    ${idx}    ${split}    IN ENUMERATE    @{path_splits}  start=1
        Log    ${idx} - ${split}
        ${present}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key    dictionary=${value}    key=${split}
        IF    ${present} == ${TRUE}
            ${value}=    Set Variable    ${value["${split}"]}
        ELSE
            ${value}=    Set Variable    ${EMPTY}
            Log    message=${path} or part of it is not found in the given JSON
            ...    level=ERROR
            BREAK
        END
    END
    RETURN    ${value}

Extract URLs From Text
    [Documentation]    Reads a text and extracts portions which match the pattern
    ...                of a URL
    [Arguments]    ${text}
    ${urls}=     Get Regexp Matches   ${text}   (?:(?:(?:ftp|http)[s]*:\/\/|www\.)[^\.]+\.[^ \n]+)
    RETURN    ${urls}

Run And Verify Command
    [Documentation]    Run and verify shell command
    [Arguments]    ${command}    ${print_to_log}=${TRUE}    ${expected_rc}=${0}
    ${result}=    Run Process    ${command}    shell=yes    stderr=STDOUT
    IF    ${print_to_log}    Log    ${result.stdout}     console=True
    Should Be True    ${result.rc} == ${expected_rc}
    RETURN    ${result.stdout}

Run And Watch Command
  [Documentation]    Run any shell command (including args) with optional:
  ...    Timeout: 10 minutes by default.
  ...    Output Should Contain: Verify an excpected text to exists in command output.
  ...    Output Should Not Contain: Verify an excpected text to not exists in command output.
  [Arguments]    ${command}    ${timeout}=10 min   ${output_should_contain}=${NONE}    ${output_should_not_contain}=${NONE}
  ...            ${cwd}=${CURDIR}
  Log    Watching command output: ${command}   console=True
  ${is_test}=    Run keyword And Return Status    Variable Should Exist     ${TEST NAME}
  IF    ${is_test} == ${FALSE}
    ${incremental}=    Generate Random String    5    [NUMBERS]
    ${TEST NAME}=    Set Variable    testlogs-${incremental}
  END
  ${process_log} =    Set Variable    ${OUTPUT DIR}/${TEST NAME}.log
  ${temp_log} =    Set Variable    ${TEMPDIR}/${TEST NAME}.log
  Create File    ${process_log}
  Create File    ${temp_log}
  ${process_id} =    Start Process    ${command}    shell=True    stdout=${process_log}
  ...    stderr=STDOUT    cwd=${cwd}
  Log    Shell process started in the background   console=True
  Wait Until Keyword Succeeds    ${timeout}    10 s
  ...    Check Process Output and Status    ${process_id}    ${process_log}    ${temp_log}
  ${proc_result} =	    Wait For Process    ${process_id}    timeout=3 secs
  Terminate Process    ${process_id}    kill=true
  Should Be Equal As Integers	    ${proc_result.rc}    0    msg=Error occured while running: ${command}
  IF  "${output_should_contain}" != "${NONE}"
    ${result} =    Run Process 	grep '${output_should_contain}' '${process_log}'    shell=yes
    Should Be True    ${result.rc} == 0    msg='${process_log}' should contain '${output_should_contain}'
  END
  IF  "${output_should_not_contain}" != "${NONE}"
    ${result} =    Run Process 	grep -L '${output_should_not_contain}' '${process_log}' | grep .    shell=yes
    Should Be True    ${result.rc} == 0    msg='${process_log}' should not contain '${output_should_not_contain}'
  END
  RETURN    ${proc_result.rc}

Check Process Output and Status
  [Documentation]    Helper keyward for 'Run And Watch Command', to tail proccess and check its status
  [Arguments]    ${process_id}    ${process_log}    ${temp_log}
  Log To Console    .    no_newline=true
  ${log_data} = 	Get File 	${process_log}
  ${temp_log_data} = 	Get File 	${temp_log}
  ${last_line_index} =    Get Line Count    ${temp_log_data}
  @{new_lines} =    Split To Lines    ${log_data}    ${last_line_index}
  FOR    ${line}    IN    @{new_lines}
      Log To Console    ${line}
  END
  Create File    ${temp_log}    ${log_data}
  Process Should Be Stopped	    ${process_id}

Escape String Chars
    [Arguments]    ${str}    ${chars}=@{DEFAULT_CHARS_TO_ESCAPE}
    FOR    ${char}    IN    @{chars}
        ${str}=    Replace String   ${str}    ${char}    \\${char}
    END
    RETURN    ${str}

Skip If Component Is Not Enabled
    [Documentation]    Skips test if ${component_name} is not enabled in DataScienceCluster
    [Arguments]    ${component_name}
    ${enabled}=    Is Component Enabled    ${component_name}
    Skip If    "${enabled}" == "false"

Enable User Workload Monitoring
    [Documentation]    Enable User Workload Monitoring for the cluster for user-defined-projects
    ${return_code}    ${output}    Run And Return Rc And Output   oc apply -f ${UWM_ENABLE_FILEPATH}
    Log To Console    ${output}
    IF    "already exists" in $output
        Log    configmap already existed on the cluster, continuing
        RETURN
    ELSE
        Should Be Equal As Integers    ${return_code}     0   msg=Error while applying the provided file
    END

Configure User Workload Monitoring
    [Documentation]    Configure the retention period in User Workload Monitoring for the cluster.
    ...                This period can be configured for the component as and when needed.
    ${return_code}    ${output}    Run And Return Rc And Output   oc apply -f ${UWM_CONFIG_FILEPATH}
    Log To Console    ${output}
    IF    "already exists" in $output
        Log    configmap already existed on the cluster, continuing
        RETURN
    ELSE
        Should Be Equal As Integers    ${return_code}     0   msg=Error while applying the provided file
    END

Clear Element And Input Text
    [Documentation]    Clear and input text element, wait .5 seconds and input new text on it
    [Arguments]    ${element_xpath}    ${new_text}
    Clear Element Text    ${element_xpath}
    Sleep    0.5s
    Input Text    ${element_xpath}    ${new_text}

Clone Git Repository
    [Documentation]   Clone Git repository in local framework
    [Arguments]    ${REPO_URL}    ${REPO_BRANCH}    ${DIR}
    ${result} =    Run Process    git clone -b ${REPO_BRANCH} ${REPO_URL} ${DIR}
    ...    shell=true    stderr=STDOUT
    Log To Console    ${result.stdout}
    IF    ${result.rc} != 0
        FAIL    Unable to clone DW repo ${REPO_URL}:${REPO_BRANCH}:${DIR}
    END

Get Operator Starting Version
    [Documentation]    Returns the starting version of the operator in the upgrade chain
    ${rc}    ${out}=    Run And Return RC And Output
    ...    oc get subscription rhods-operator -n ${OPERATOR_NAMESPACE} -o yaml | yq -r '.spec.startingCSV' | awk -F. '{print $2"."$3"."$4}'    # robocop: disable
    Should Be Equal As Integers    ${rc}    0
    RETURN    ${out}

Is Starting Version Supported
    [Documentation]    Returns ${TRUE} if the starting version of the upgrade chain is allowed (i.e. >= minimum allowed
    ...    version), ${FALSE} otherwise.
    [Arguments]    ${minimum_version}
    ${starting_ver}=    Get Operator Starting Version
    ${out}=     Gte    ${starting_ver}    ${minimum_version}
    RETURN    ${out}

Skip If Operator Starting Version Is Not Supported
    [Documentation]    Skips test if ODH/RHOAI operator starting version is < ${minimum_version}
    ...    Usage example: add    Skip If Operator Starting Version Is Not Supported    minimum_version=2.14.0
    ...    in your post-upgrade tests if the resources needed by them were added in the pre-upgrade suite
    ...    in ods-ci release-2.14
    [Arguments]    ${minimum_version}
    ${supported}=    Is Starting Version Supported    minimum_version=${minimum_version}
    Skip If    condition="${supported}"=="${FALSE}"    msg=This test is skipped because starting operator version < ${minimum_version}

Skip If Cluster Type Is Self-Managed
    [Documentation]    Skips test if cluster type is Self-managed
    ${cluster_type}=    Is Cluster Type Managed
    Skip If    condition=${cluster_type}==False    msg=This test is skipped for Self-managed cluster

Skip If Cluster Type Is Managed
    [Documentation]    Skips test if cluster type is Managed
    ${cluster_type}=    Is Cluster Type Managed
    Skip If    condition=${cluster_type}==True    msg=This test is skipped for Managed cluster

Delete All ${resource_type} In Namespace By Name
    [Documentation]    Force delete all ${resource_type} named '${resource_type}' in namespace '${namespace}'
    [Arguments]    ${namespace}    ${resource_name}
    ${list_resources} =    Set Variable    oc -n ${namespace} get ${resource_type} -o name | grep /${resource_name}
    ${xargs_patch} =    Set Variable    xargs -rt oc -n ${namespace} patch --type=json -p '[{"op": "add", "path": "/metadata/ownerReferences", "value": null}]'
    ${xargs_delete} =    Set Variable    xargs -rt oc -n ${namespace} delete
    ${result} =    Run Process    ${list_resources} | ${xargs_patch} && ${list_resources} | ${xargs_delete}
    ...    shell=true    stderr=STDOUT
    Log    ${result.stdout}    console=yes
