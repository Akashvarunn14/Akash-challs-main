# akvnn Web & Pwn CTF Challenges

Welcome to **Akash-challs** — a collection of **Web and Pwn CTF challenges** built to feel realistic and practical.

These challenges aren’t meant to spoon-feed. You’re expected to **read code, break assumptions, and think like an attacker**. The goal is to mirror how vulnerabilities actually show up in real systems.

---

## What’s in here?

This repo mainly focuses on:
- Web exploitation challenges  
- Logic bugs & auth issues  
- Input handling mistakes  
- Misconfigurations  
- Binary exploitation (pwn) challenges  

Each challenge is designed to:
- Look normal at first
- Avoid obvious hints
- Force source code analysis
- Encourage chaining multiple bugs

---

## Writeups

Each challenge contains a **`writeup.md`** file.

That file includes:
- Vulnerability analysis
- Exploitation steps
- Payloads / scripts (if any)
- Final flag retrieval

If you’re stuck or reviewing later, that’s where the full breakdown lives.

---

## Repository Structure

```text
Akash-challs/
├── challenge-name/
│   ├── app/              # Source code
│   ├── docker-compose.yml
│   ├── README.md         # Challenge description
│   ├── writeup.md        # Full solution & explanation
│   └── flag.txt          # Server-side flag
│
├── another-challenge/
│   └── ...
│
└── README.md             # see the writeup
