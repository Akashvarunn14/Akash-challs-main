from flask import Flask, request, render_template, redirect, session, url_for
import sqlite3
import requests
import socket
import struct
import os

app = Flask(__name__)
app.secret_key = 'super_secret_key_for_session_signing'

def init_db():
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute('CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, username TEXT, password TEXT)')
    # Insert admin user if not exists
    c.execute("SELECT * FROM users WHERE username='admin'")
    if not c.fetchone():
        c.execute("INSERT INTO users (username, password) VALUES ('admin', 'Th1s_1s_A_V3ry_Str0ng_P4ssw0rd_Y0u_W0nt_Gu3ss')")
    conn.commit()
    conn.close()

init_db()

@app.route('/', methods=['GET'])
def index():
    return render_template('login.html')

@app.route('/login', methods=['POST'])
def login():
    username = request.form.get('username')
    password = request.form.get('password')

    # HARDENING: Blacklist Filter
    blacklist = [" "]
    for item in blacklist:
        if item in username or item in password:
            return render_template('login.html', error="Security Alert: Malicious Input Detected")
    
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    
    # VULNERABLE QUERY
    query = f"SELECT * FROM users WHERE username = '{username}' AND password = '{password}'"
    try:
        c.execute(query)
        user = c.fetchone()
    except Exception as e:
        conn.close()
        return f"Database Error: {e}"
    
    conn.close()
    
    if user:
        session['user'] = user[1]
        return redirect(url_for('sanctum'))
    else:
        return render_template('login.html', error="Invalid credentials")

@app.route('/sanctum', methods=['GET', 'POST'])
def sanctum():
    if 'user' not in session:
        return redirect(url_for('index'))
    
    result = None
    if request.method == 'POST':
        url = request.form.get('url')
        if url:
            # SSRF PROTECTION (Blacklist)
            blacklist = ["localhost", "127.0.0.1", "2130706433", "0.0.0.0", "0177.0.0.1"]
            if any(b in url for b in blacklist):
                result = "The scroll cannot look at itself directly (Localhost Forbidden)."
            else:
                try:
                    # Allow redirects to follow through
                    resp = requests.get(url, timeout=5)
                    result = resp.text
                except Exception as e:
                    result = f"The scroll is confused: {e}"
        else:
            result = "You must provide a location for the scroll to see."

    return render_template('sanctum.html', result=result)

@app.route('/master_seal')
def master_seal():
    # Only allow access from localhost
    remote_ip = request.remote_addr
    if remote_ip != '127.0.0.1':
        return "Forbidden: The Master Seal is only visible to the inner sanctum."
    
    flag = os.environ.get('FLAG', 'L3m0nCTF{G4NG5T3R_G4N35H_SQLi_Byp4ss_4nd_D3c1m4l_IP_SSrf_}')
    return flag

if __name__ == '__main__':
    # Production ready settings
    app.run(host='0.0.0.0', port=5002, debug=False)
