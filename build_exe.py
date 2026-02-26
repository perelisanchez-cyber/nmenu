#!/usr/bin/env python3
"""
Build script for compiling Roblox Manager to a standalone exe.
This avoids Python detection by executors like Volt.

Requirements:
    pip install pyinstaller

Usage:
    python build_exe.py

Output:
    dist/RobloxManager.exe
"""

import subprocess
import sys
import os

def main():
    # Ensure PyInstaller is installed
    try:
        import PyInstaller
    except ImportError:
        print("[*] Installing PyInstaller...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])

    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    manager_path = os.path.join(script_dir, "roblox_manager__39_.py")

    if not os.path.exists(manager_path):
        print(f"[!] Error: {manager_path} not found")
        sys.exit(1)

    print("[*] Building Roblox Manager exe...")
    print(f"[*] Source: {manager_path}")

    # PyInstaller command
    # --onefile: Single exe file
    # --noconsole: No console window (GUI app) - REMOVED so we can see debug output
    # --name: Output filename
    # --icon: Optional icon file
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--onefile",
        "--name", "RobloxManager",
        "--add-data", f"{script_dir};.",  # Include current directory for data files
        manager_path
    ]

    print(f"[*] Running: {' '.join(cmd)}")

    result = subprocess.run(cmd, cwd=script_dir)

    if result.returncode == 0:
        exe_path = os.path.join(script_dir, "dist", "RobloxManager.exe")
        print(f"\n[+] Success! Exe built at: {exe_path}")
        print(f"[*] Copy RobloxManager.exe to the folder with your roblox_manager_data.json")
    else:
        print(f"\n[!] Build failed with code {result.returncode}")
        sys.exit(1)

if __name__ == "__main__":
    main()
