# MobileAppiumLibrary.py
"""
Custom Robot Framework library for Mobile automation using Appium.
"""

from robot.api.deco import keyword
from appium import webdriver
import subprocess
import os
from pathlib import Path

class MobileAppiumLibrary:
    def __init__(self):
        self.driver = None

    @keyword
    def start_session(self, desired_caps, command_executor='http://localhost:4723'):
        # Try multiple ways to start a session to be compatible with different
        # Appium/Selenium client versions: prefer AppiumOptions, then try
        # 'capabilities' or 'desired_capabilities' keywords, then positional.
        desired_caps = desired_caps or {}
        import inspect

        # If this is a Chrome browser session and no chromedriverExecutable is
        # provided, try to fetch a matching chromedriver for the device and
        # set the capability so Appium can use it.
        try:
            bname = (desired_caps.get('browserName') or desired_caps.get('browsername') or '').lower()
        except Exception:
            bname = ''
        if bname in ('chrome', 'chromium') and not desired_caps.get('chromedriverExecutable'):
            try:
                project_root = Path(__file__).resolve().parents[1]
                script = project_root / 'scripts' / 'get_chromedriver_for_device.sh'
                device = desired_caps.get('deviceName', 'emulator-5554')
                if script.exists() and os.access(script, os.X_OK):
                    completed = subprocess.run([str(script), str(device)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, encoding='utf8')
                    cd_path = completed.stdout.strip()
                    if cd_path:
                        desired_caps['chromedriverExecutable'] = cd_path
                elif script.exists():
                    # try to make it executable then run
                    os.chmod(script, 0o755)
                    completed = subprocess.run([str(script), str(device)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, encoding='utf8')
                    cd_path = completed.stdout.strip()
                    if cd_path:
                        desired_caps['chromedriverExecutable'] = cd_path
            except subprocess.CalledProcessError as err:
                # log but continue — Appium may attempt automatic download if allowed
                pass

        # Build an AppiumOptions object if available; else we'll use the dict
        opts = None
        try:
            from appium.options.common import AppiumOptions
            opts = AppiumOptions()
            for k, v in desired_caps.items():
                try:
                    opts.set_capability(k, v)
                except Exception:
                    pass
        except Exception:
            opts = None

        # Inspect the constructor to determine accepted keyword names
        try:
            sig = inspect.signature(webdriver.Remote.__init__)
            params = set(sig.parameters.keys())
        except Exception:
            params = set()

        attempts = []
        errors = {}

        # Prefer 'options' if supported and we have an AppiumOptions instance
        if opts is not None and 'options' in params:
            attempts.append(('options', opts))

        # Next try 'capabilities' or 'desired_capabilities' if supported
        if 'capabilities' in params:
            attempts.append(('capabilities', getattr(opts, 'capabilities', desired_caps) if opts is not None else desired_caps))
        if 'desired_capabilities' in params:
            attempts.append(('desired_capabilities', desired_caps))

        # If no keyword info available, fall back to trying common kws in order
        if not attempts:
            attempts = [('options', opts), ('capabilities', desired_caps), ('desired_capabilities', desired_caps)]

        for kw, val in attempts:
            if val is None:
                continue
            try:
                kwargs = {kw: val}
                self.driver = webdriver.Remote(command_executor=command_executor, **kwargs)
                return
            except TypeError as te:
                errors[kw] = str(te)
                continue
            except Exception as e:
                errors[kw] = str(e)
                continue
        # Build a detailed error message with each attempt's exception
        detail_lines = [f"{k}: {v}" for k, v in errors.items()]
        raise RuntimeError(f"Failed to start Appium session. Attempts:\n" + "\n".join(detail_lines))

    @keyword
    def click(self, element_id):
        # Selenium/Appium client may use new find_element API
        locator = element_id
        # support locator formats like "id=...", "xpath=...", "css=..."
        if isinstance(locator, str) and '=' in locator:
            strategy, value = locator.split('=', 1)
            strategy = strategy.strip().lower()
            # map common short names to Selenium/Appium strategy names
            strategy_map = {
                'id': 'id',
                'xpath': 'xpath',
                'name': 'name',
                'class': 'class name',
                'class_name': 'class name',
                'tag': 'tag name',
                'link': 'link text',
                'partiallink': 'partial link text',
                'partial_link': 'partial link text',
                'css': 'css selector',
                'css_selector': 'css selector'
            }
            by = strategy_map.get(strategy, 'id')
            try:
                self.driver.find_element(by, value).click()
                return
            except Exception:
                pass
        # fallback to legacy id-based lookup
        try:
            self.driver.find_element('id', locator).click()
        except Exception:
            self.driver.find_element_by_id(locator).click()

    @keyword
    def go_to(self, url):
        # navigate to a URL in the current browser session
        try:
            self.driver.get(url)
        except Exception as e:
            raise RuntimeError(f"Failed to navigate to {url}: {e}")

    @keyword
    def close_session(self):
        self.driver.quit()
