*** Settings ***
Library    ../libraries/DBLibrary.py    test.db

*** Test Cases ***
Execute Query Test
    ${result}=    Execute Query    SELECT sqlite_version();
    Should Not Be Empty    ${result}
    Close
