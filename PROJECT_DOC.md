# Documentation

## Project Structure
- libraries/: Custom Robot Framework libraries for MQTT, Kafka, REST, DB, UI, Mobile, Firmware
- tests/: Sample test suites for each interface
- mcp-server/: AI MCP server (FastAPI skeleton, integration script)
- .github/workflows/: GitHub Actions CI pipeline
- .ci/: GitLab CI and Jenkins pipelines

## Usage
1. Install Python and dependencies (see CI scripts)
2. Add/extend libraries in libraries/
3. Add test cases in tests/
4. Start MCP server (uvicorn main:app --reload)
5. Use integrate_robot.py to generate and run tests from intent
6. Configure CI/CD as needed

## AI Layer
- MCP server interprets test intent, generates Robot test cases, self-heals, and recommends improvements

## CI/CD
- GitHub Actions, GitLab CI, Jenkins pipelines automate test execution and reporting

---
For more, see README.md and copilot-instructions.md in .github/