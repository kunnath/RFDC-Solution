FROM jenkins/jenkins:lts

USER root

# avoid prompts during apt operations
ENV DEBIAN_FRONTEND=noninteractive

# Install base system packages needed by all layers
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl wget git build-essential default-jdk python3 python3-pip python3-venv \
        android-tools-adb android-tools-fastboot \
        librdkafka-dev libssl-dev libffi-dev \
        libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libxkbcommon0 \
        libxcomposite1 libxrandr2 libxdamage1 libxfixes3 libglib2.0-0 libasound2 libgbm1 libgtk-3-0 \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (required by Playwright, Appium, etc.)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get update && apt-get install -y nodejs && \
    # global Node tools used by tests
    npm install -g appium allure-commandline --save-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Python libraries required for the test layers
# create an isolated virtual environment to avoid PEP 668 restrictions
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip \
    && /opt/venv/bin/pip install robotframework paho-mqtt confluent-kafka requests \
           playwright appium-python-client pyserial \
    && /opt/venv/bin/playwright install \
    && ln -s /opt/venv/bin/robot /usr/local/bin/robot \
    && ln -s /opt/venv/bin/python /usr/local/bin/python

# drop back to the unprivileged Jenkins user
USER jenkins