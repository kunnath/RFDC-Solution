# FirmwareLibrary.py
"""
Custom Robot Framework library for Firmware interface (serial example).
"""

from robot.api.deco import keyword
import serial

class FirmwareLibrary:
    def __init__(self, port, baudrate=9600):
        self.ser = serial.Serial(port, baudrate)

    @keyword
    def send_command(self, command):
        self.ser.write(command.encode())

    @keyword
    def read_response(self):
        return self.ser.readline().decode()

    @keyword
    def close(self):
        self.ser.close()
