*** Settings ***
Library    ../libraries/KafkaLibrary.py

*** Test Cases ***
Produce And Consume Kafka Message
    Produce    test-topic    Hello Kafka
    ${msg}=    Consume    test-topic    2.0
    Should Be Equal    ${msg}    Hello Kafka
