*** Settings ***
Library    ../libraries/UIPlaywrightLibrary.py

*** Variables ***
${UI_HEADLESS}    ${True}    # overridden via --variable when launching through frontend
${UI_BROWSER}    chromium   # can be chromium|firefox|webkit via --variable
${BASE URL}    https://www.dinexora.de
# default selector for main navigation links, adapt if the site structure changes
${MENU SELECTOR}    css=nav a

*** Test Cases ***
Open And Click UI
    [Documentation]    Basic sanity check that the home page loads and the
    ...                first hyperlink can be clicked.
    Log    Running browser ${UI_BROWSER} headless=${UI_HEADLESS}
    Open Browser    ${BASE URL}
    Click    css=a
    Close Browser

Menu Navigation Validation
    [Documentation]    Iterate through all menu items defined by
    ...                `${MENU SELECTOR}` and ensure each one resolves to a
    ...                reachable page (status < 400).
    Open Browser    ${BASE URL}
    # gather the links so we can report what we're about to check
    ${menu_links}=    Get Menu Links    ${MENU SELECTOR}
    ${count}=       Get Length    ${menu_links}
    Log    Found ${count} menu items: ${menu_links}
    Validate Menu Navigation    ${MENU SELECTOR}
    Close Browser
