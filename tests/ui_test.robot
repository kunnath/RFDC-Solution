*** Settings ***
Library    ../libraries/UIPlaywrightLibrary.py

*** Test Cases ***
Open And Click UI
    Open Browser    https://example.com
    # Click the first link on the page (example.com main link)
    Click    css=a
    Close Browser
