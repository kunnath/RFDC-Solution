# DBLibrary.py
"""
Custom Robot Framework library for DB interface.
"""

from robot.api.deco import keyword
import sqlite3

class DBLibrary:
    def __init__(self, db_path):
        self.conn = sqlite3.connect(db_path)
        self.cursor = self.conn.cursor()

    @keyword
    def execute_query(self, query):
        self.cursor.execute(query)
        return self.cursor.fetchall()

    @keyword
    def close(self):
        self.conn.close()
