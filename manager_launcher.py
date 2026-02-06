#!/usr/bin/env python3
"""
Roblox Manager Launcher
Automatically fetches and runs the latest version from GitHub.
"""

import urllib.request
import sys
import os

# GitHub raw URL for the manager script
GITHUB_RAW_URL = "https://raw.githubusercontent.com/perelisanchez-cyber/nmenu/claude/github-integration-exploration-DKPUS/roblox_manager__39_.py"

def main():
    print("=" * 50)
    print("  Roblox Manager Launcher")
    print("  Fetching latest version from GitHub...")
    print("=" * 50)

    try:
        # Fetch the latest code from GitHub
        with urllib.request.urlopen(GITHUB_RAW_URL, timeout=30) as response:
            code = response.read().decode('utf-8')

        print(f"Successfully fetched {len(code):,} bytes")
        print("Starting manager...\n")

        # Execute the fetched code
        exec(code, {'__name__': '__main__', '__file__': 'roblox_manager.py'})

    except urllib.error.URLError as e:
        print(f"Failed to fetch from GitHub: {e}")
        print("\nCheck your internet connection and try again.")
        input("Press Enter to exit...")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        input("Press Enter to exit...")
        sys.exit(1)

if __name__ == "__main__":
    main()
