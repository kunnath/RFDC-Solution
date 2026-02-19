*** Settings ***
Library    ../libraries/FirmwareLibrary.py    /dev/ttyUSB0    9600

*** Test Cases ***
Send And Read Firmware Command
    Send Command    STATUS
    ${resp}=    Read Response
    Should Contain    ${resp}    OK
    Close
