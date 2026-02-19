# UIPlaywrightLibrary.py
"""
Custom Robot Framework library for UI automation using Playwright.
"""

from robot.api.deco import keyword
from playwright.sync_api import sync_playwright


class UIPlaywrightLibrary:
    def __init__(self):
        self._playwright = None
        self.browser = None
        self.page = None

    def _ensure_playwright(self):
        if not self._playwright:
            # start Playwright so it stays active across keywords
            self._playwright = sync_playwright().start()

    @keyword
    def open_browser(self, url):
        self._ensure_playwright()
        if self.browser:
            try:
                self.browser.close()
            except Exception:
                pass
        self.browser = self._playwright.chromium.launch()
        self.page = self.browser.new_page()
        self.page.goto(url)

    @keyword
    def click(self, selector):
        if not self.page:
            raise RuntimeError('No open page - call Open Browser first')
        self.page.click(selector)

    @keyword
    def close_browser(self):
        if self.browser:
            try:
                self.browser.close()
            except Exception:
                pass
            self.browser = None
            self.page = None
        if self._playwright:
            try:
                self._playwright.stop()
            except Exception:
                pass
            self._playwright = None
