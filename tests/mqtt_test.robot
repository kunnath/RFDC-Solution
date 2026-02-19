*** Settings ***
Library    ../libraries/MQTTLibrary.py

*** Test Cases ***
Connect To MQTT Broker
    Connect    localhost    1883
    Publish    test/topic    Hello World
    Subscribe  test/topic
    Disconnect
