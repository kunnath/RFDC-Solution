*** Settings ***
Library    ../libraries/MQTTLibrary.py

*** Test Cases ***
Connect To MQTT Broker
    Connect    localhost    5000
    Publish    test/topic    Hello World
    Subscribe  test/topic
    Disconnect
