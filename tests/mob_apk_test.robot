*** Settings ***
Library    ../libraries/MobileAppiumLibrary.py

*** Variables ***
${APK}    ../apps/demo.apk          # adjust path as required

*** Test Cases ***
Open Mobile App And Run Demo
    # capabilities for a local Android emulator; replace deviceName, etc. as needed
    ${caps}=    Create Dictionary
    ...    platformName=Android
    ...    deviceName=emulator-5554
    ...    automationName=UiAutomator2
    ...    app=${APK}

    Start Session    ${caps}

    # give the app a moment to start
    Sleep    5s

    # add any interactions you want here, e.g.
    # Click    xpath=//android.widget.Button[@text='Continue']
    # ${text}=    Get Text    id=com.example.demo:id/welcomeLabel
    # Should Be Equal    ${text}    Welcome to Demo

    Close Session