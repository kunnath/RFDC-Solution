# RFDC Framework

This project is a modular Robot Framework-based test automation solution with custom libraries for MQTT, Kafka, REST APIs, DB, UI (Playwright), Mobile (Appium), and Firmware interfaces. It includes an AI MCP server for test intent interpretation, self-healing, and recommendations, and integrates with CI/CD pipelines (GitHub Actions, GitLab CI, Jenkins).

## Structure
- libraries/: Custom Robot Framework libraries
- tests/: Sample test suites
- mcp-server/: AI layer (MCP server)
- .github/: GitHub Actions workflows
- .ci/: CI/CD scripts for GitLab/Jenkins

## Getting Started
1. Install Python, Robot Framework, and required libraries
2. Add/extend custom libraries in libraries/
3. Add test cases in tests/
4. Start MCP server for AI features
5. Configure CI/CD as needed

## Roadmap
- [ ] Implement custom libraries
- [ ] Develop MCP server
- [ ] Integrate CI/CD pipelines
- [ ] Add documentation

---
For details, see copilot-instructions.md in .github/# RFDC-Solution
