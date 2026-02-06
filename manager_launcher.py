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

    # Get the directory where this launcher script is located
    # This is where we expect roblox_manager_data.json to be
    launcher_dir = os.path.dirname(os.path.abspath(__file__))
    manager_path = os.path.join(launcher_dir, "roblox_manager.py")

    # Change to the launcher's directory so relative paths work
    os.chdir(launcher_dir)
    print(f"Working directory: {launcher_dir}")

    # Check for data file
    data_file = os.path.join(launcher_dir, "roblox_manager_data.json")
    if os.path.exists(data_file):
        print(f"Found data file: {data_file}")
    else:
        print(f"WARNING: Data file not found at: {data_file}")
        print("Looking for files in directory:")
        for f in os.listdir(launcher_dir):
            if 'manager' in f.lower() or 'data' in f.lower() or f.endswith('.json') or f.endswith('.txt'):
                print(f"  - {f}")

    try:
        # Fetch the latest code from GitHub
        with urllib.request.urlopen(GITHUB_RAW_URL, timeout=30) as response:
            code = response.read().decode('utf-8')

        print(f"Successfully fetched {len(code):,} bytes")
        print("Starting manager...\n")

        # Execute the fetched code with proper __file__ set to launcher's directory
        # This ensures DATA_FILE path resolves correctly
        exec(code, {'__name__': '__main__', '__file__': manager_path})

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
