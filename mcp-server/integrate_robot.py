# Example integration script for MCP server and Robot Framework
import requests
import os

def generate_robot_test(intent):
    resp = requests.post('http://localhost:8000/interpret-intent', json={'intent': intent})
    robot_test = resp.json().get('robot_test_case', '')
    with open('generated_test.robot', 'w') as f:
        f.write(robot_test)
    return 'generated_test.robot'

if __name__ == '__main__':
    intent = 'Test login functionality'
    test_file = generate_robot_test(intent)
    os.system(f'robot {test_file}')
