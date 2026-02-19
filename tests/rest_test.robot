*** Settings ***
Library    ../libraries/RESTLibrary.py

*** Test Cases ***
Get Request Test
    ${resp}=    Get    https://jsonplaceholder.typicode.com/posts/1
    Should Contain    ${resp}    userId

Post Request Test
    ${resp}=    Post    https://jsonplaceholder.typicode.com/posts    json={"title": "foo", "body": "bar", "userId": 1}
    Should Contain    ${resp}    id
