# MQTTLibrary.py
"""
Custom Robot Framework library for MQTT interface.
"""

from robot.api.deco import keyword
import paho.mqtt.client as mqtt

class MQTTLibrary:
    def __init__(self):
        self.client = mqtt.Client()

    @keyword
    def connect(self, host, port=1883):
        self.client.connect(host, port)

    @keyword
    def publish(self, topic, payload):
        self.client.publish(topic, payload)

    @keyword
    def subscribe(self, topic):
        self.client.subscribe(topic)

    @keyword
    def disconnect(self):
        self.client.disconnect()
