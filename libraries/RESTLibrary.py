# RESTLibrary.py
"""
Custom Robot Framework library for REST APIs.
"""

from robot.api.deco import keyword
import requests

class RESTLibrary:
    @keyword
    def get(self, url, params=None):
        response = requests.get(url, params=params)
        return response.json()

    @keyword
    def post(self, url, data=None, json=None):
        response = requests.post(url, data=data, json=json)
        return response.json()
