# ## Certificate level II - Build a robot
#
# RPA solution
#

*** Settings ***
Documentation   Orders robots from RobotSpareBin Industries Inc.
...             Saves the order HTML receipt as a PDF file.
...             Saves the screenshot of the ordered robot.
...             Embeds the screenshot of the robot to the PDF receipt.
...             Creates ZIP archive of the receipts and the images.
Library         RPA.Browser.Selenium
Library         RPA.HTTP
Library         RPA.Tables
Library         RPA.PDF
Library         RPA.FileSystem
Library         RPA.Archive
Library         RPA.Robocloud.Secrets
Library         RPA.Dialogs

*** Keywords ***
Get Orders Default Location
    ${secret}=      Get Secret    important_data
    [Return]    ${secret}[order]

*** Keywords ***
Get Location of Output Directory
    ${secret}=      Get Secret      important_data
    [Return]    ${secret}[output_location]

*** Keywords ***
Get Url Address
    ${secret}=      Get Secret      important_data
    Log     ${secret}[url]
    [Return]    ${secret}[url]

*** Keywords ***
Open the robot ordering site
    ${url}=     Get Url Address
    Open Available Browser  ${url}
    Maximize Browser Window

*** Keywords ***
Input orders file or default
    Add heading       Orders file location
    Add file input    name=types     file_type=CSV files (*.csv)
    Add submit buttons    buttons=Cancel,Submit
    ${result}=    Run dialog
    [Return]    ${result}

*** Keywords ***
Confirmation dialog for default orders file
    Add icon              Warning
    Add heading           File not found or not entered
    Add text    Proceed with default file
    Add submit buttons    buttons=Ok
    Run dialog    title=Warning

*** Keywords ***
Download orders file
    [Arguments]     ${orders_location}
    ${control_value}    Set Variable    Cancel   
    IF  '${orders_location}[submit]'=='${control_value}'
        Confirmation dialog for default orders file
        Get Csv File    True
    ELSE
        ${x}=    Get Length  ${orders_location}[types]
        IF    ${x}==0
            Log    File location not entered
            Confirmation dialog for default orders file
            Get Csv File      True
        ELSE
            Log    Path to the csv file is saved
            Get Csv File      False    ${orders_location}[types][0]
        END
    END

*** Keywords ***
Get Csv File
    [Arguments]     ${default_loc}    ${file_location}=null
    IF    ${default_loc} == True
        ${order_default_location}=    Get Orders Default Location
        Download    ${order_default_location}  overwrite=True
        Log    File downloaded from default location.
    ELSE
        Copy File    ${file_location}   ${CURDIR}${/}orders.csv
        Log    File uploaded from local machine.
    END

*** Keywords ***
Read orders file
    ${orders_from_file}=    Read table from CSV    orders.csv
    Remove File    orders.csv
    [Return]    ${orders_from_file}

*** Keywords ***
Make Orders Single
    Click Button    css:.btn-danger
    Select From List By Index    id:head    3
    Click Element    id:id-body-5
    Input Text    xpath://label[contains(.,'3. Legs:')]/../input   2
    Input Text    id:address    New York
    Click Button    id:preview
    Click Button    id:order
    Click Button    id:order-another

*** Keywords ***
Make Orders
    [Arguments]     ${orders_from_file}
    FOR    ${row}    IN    @{orders_from_file}
           Click Button    css:.btn-danger
           ${target_as_integer}     Convert To Integer  ${row}[Head]
           Log  ${target_as_integer}
           Select From List By Index    id:head    ${target_as_integer}
           ${target_radio_button}=  Catenate    SEPARATOR=     id:id-body-  ${row}[Body]
           Click Element    ${target_radio_button}
           Input Text    xpath://label[contains(.,'3. Legs:')]/../input   ${row}[Legs]
           Input Text    id:address    ${row}[Address]
           Click Button    id:preview
           FOR    ${i}    IN RANGE    9999999
                Click Button    id:order
                ${error_message}=    Does Page Contain Element    id:order-another
                Log  ${error_message}
                Exit For Loop If    ${error_message}==True
           END
           ${pdf_location}=     Store the receipt as a PDF file     ${row}[Order number]
           ${screenshot}=       Take a screenshot of the robot    ${row}[Order number]
           Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf_location}
           Click Button    id:order-another
           
    END

*** Keywords ***
Embed the robot screenshot to the receipt PDF file
    [Arguments]     ${screenshot}   ${pdf_location}
    Open Pdf    ${pdf_location}
    Add Watermark Image To Pdf    
    ...      image_path=${screenshot}
    ...      output_path=${pdf_location}
    Close Pdf   ${pdf_location}


*** Keywords ***
Take a screenshot of the robot
    [Arguments]     ${order_number}
    ${location}=    Get Location of Output Directory
    ${location}=    Catenate    SEPARATOR=  ${location}${/}robot    ${order_number}    .png
    #${location}=    Catenate    SEPARATOR=  ${location}     .png
    Log     ${location}
    ${robot_image}=     Screenshot    id:robot-preview-image    ${location}
    [Return]    ${location}

*** Keywords ***
Store the receipt as a PDF file
    [Arguments]     ${order_number}
    ${location}=    Get Location of Output Directory
    ${location}=    Catenate    SEPARATOR=  ${location}${/}pdf${/}robot    ${order_number}    .pdf
    #${location}=    Catenate    SEPARATOR=  ${location}    .pdf
    ${receipt_html}=  Get Element Attribute    id:receipt  outerHTML
    Html To PDF     ${receipt_html}  ${location}
    [Return]    ${location}

*** Keywords ***
Create a ZIP file of the receipts
    ${location}=    Get Location of Output Directory
    Archive Folder With Zip     ${location}${/}pdf${/}     ${location}${/}orders.zip
    Remove Directory    ${location}${/}pdf      recursive=yes

*** Keywords ***
Close working browser
    Close Browser

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    ${orders_location}=     Input orders file or default
    Open the robot ordering site
    Download orders file    ${orders_location}
    ${orders_from_file}=    Read orders file
    #Make Orders Single
    Make orders             ${orders_from_file}
    Create a ZIP file of the receipts
    [Teardown]  Close working browser
