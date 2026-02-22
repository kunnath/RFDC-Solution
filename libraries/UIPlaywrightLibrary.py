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
        # decide headless vs headed based on Robot variable (UI_HEADLESS)
        headless = True
        browser_type = 'chromium'
        try:
            from robot.libraries.BuiltIn import BuiltIn
            val = BuiltIn().get_variable_value("${UI_HEADLESS}", None)
            if val is not None:
                headless = str(val).strip().lower() in ("true", "1", "yes", "y")
            bval = BuiltIn().get_variable_value("${UI_BROWSER}", None)
            if bval is not None:
                bstr = str(bval).strip().lower()
                if bstr in ('chromium', 'firefox', 'webkit'):
                    browser_type = bstr
        except Exception:
            # if something goes wrong retrieving variable, stick with defaults
            pass
        # emit a console log to stderr so node/spawnSync captures it reliably
        try:
            import sys
            sys.stderr.write(f"[UIPlaywrightLibrary] launching {browser_type} headless={headless}\n")
        except Exception:
            pass
        # choose launch based on browser_type
        if browser_type == 'firefox':
            self.browser = self._playwright.firefox.launch(headless=headless)
        elif browser_type == 'webkit':
            self.browser = self._playwright.webkit.launch(headless=headless)
        else:
            self.browser = self._playwright.chromium.launch(headless=headless)
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

    @keyword
    def get_menu_links(self, selector="nav a"):
        """Return a list of href values for all elements matching *selector*.

        The selector defaults to ``nav a`` which covers a typical site
        navigation bar.  If no page is open, an error is raised.  The
        returned list may contain ``None`` values for elements without an
        ``href`` attribute so callers can filter as desired.
        """
        if not self.page:
            raise RuntimeError('No open page - call Open Browser first')
        elements = self.page.query_selector_all(selector)
        return [el.get_attribute('href') for el in elements]

    @keyword
    def validate_menu_navigation(self, selector="nav a"):
        """Navigate through each link in a menu and assert the targets are
        reachable.

        The keyword looks up all elements matching *selector* then follows
        each ``href`` it finds.  After visiting a link it navigates back so
        the remaining items can be validated.  If any link returns a
        status-code >=400 an :class:`AssertionError` is raised.
        """
        if not self.page:
            raise RuntimeError('No open page - call Open Browser first')

        elements = self.page.query_selector_all(selector)
        if not elements:
            raise AssertionError(f"No elements found for selector '{selector}'")

        # collect the values up front so we don't hold references that go stale
        items = []
        for el in elements:
            href = el.get_attribute('href')
            text = el.inner_text().strip()
            if not href:
                continue
            items.append((href, text))

        for idx, (href, text) in enumerate(items, start=1):
            # resolve relative URLs against current page.url if necessary
            target = href
            if target and not target.lower().startswith(("http://","https://")):
                base = self.page.url.rstrip("/")
                target = base + target
            response = self.page.goto(target)
            status = response.status if response else None
            if status is not None and status >= 400:
                raise AssertionError(
                    f"Menu item {idx} ('{text}') at '{href}' returned status {status}"
                )
            # go back to home page for next item
            self.page.go_back()
            self.page.wait_for_load_state('load')
