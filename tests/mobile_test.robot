*** Settings ***
Library    ../libraries/MobileAppiumLibrary.py

*** Test Cases ***
Open Mobile Browser And Click
    ${caps}=    Create Dictionary    platformName=Android    deviceName=emulator-5554    automationName=UiAutomator2    browserName=Chrome
    Start Session    ${caps}
    Go To    https://www.google.com
    Click    xpath=//a
    Close Session
