"""
Roblox Multi-Instance Manager - Desktop App
============================================
Standalone desktop application. No browser needed.
Runs HTTP server on localhost:8080 for executor communication.

Features:
  - Dark themed desktop UI (matches nigMenu aesthetic)
  - Multi-account management with Chrome cookie import
  - Multi-instance launching (mutex bypass)
  - Private server shutdown + auto-rejoin
  - Auto-restart timer for boss farming
  - Private Server Only enforcement
  - Integrated HTTP API for Lua executor

Usage:
  python roblox_manager.py

Requirements (auto-installed on first run):
  pip install pycryptodome psutil
"""

import json
import urllib.request
import urllib.error
import urllib.parse
import ssl
import time
import threading
import sys
import subprocess
import os
import shutil
import sqlite3
import base64
import tempfile
import struct
import random
import http.server
import tkinter as tk
from tkinter import ttk, messagebox, simpledialog
from datetime import datetime

# ============================================================================
# PLATFORM CHECK
# ============================================================================

IS_WINDOWS = sys.platform == "win32"

if IS_WINDOWS:
    import ctypes
    import ctypes.wintypes

    # Set up argtypes for Windows API functions to handle 64-bit HWNDs properly
    ctypes.windll.user32.GetWindowThreadProcessId.argtypes = [ctypes.wintypes.HWND, ctypes.POINTER(ctypes.wintypes.DWORD)]
    ctypes.windll.user32.GetWindowThreadProcessId.restype = ctypes.wintypes.DWORD
    ctypes.windll.user32.IsWindowVisible.argtypes = [ctypes.wintypes.HWND]
    ctypes.windll.user32.IsWindowVisible.restype = ctypes.wintypes.BOOL
    ctypes.windll.user32.GetWindowTextLengthW.argtypes = [ctypes.wintypes.HWND]
    ctypes.windll.user32.GetWindowTextLengthW.restype = ctypes.c_int
    ctypes.windll.user32.GetWindowRect.argtypes = [ctypes.wintypes.HWND, ctypes.POINTER(ctypes.wintypes.RECT)]
    ctypes.windll.user32.GetWindowRect.restype = ctypes.wintypes.BOOL
    ctypes.windll.user32.SetWindowPos.argtypes = [ctypes.wintypes.HWND, ctypes.wintypes.HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.wintypes.UINT]
    ctypes.windll.user32.SetWindowPos.restype = ctypes.wintypes.BOOL

# ============================================================================
# WINDOW LAYOUT HELPERS (Windows only)
# ============================================================================

def get_window_by_pid(pid):
    """Find the main window handle (HWND) for a given process ID."""
    if not IS_WINDOWS:
        return None

    result = []

    def enum_callback(hwnd, lparam):
        # Get the PID for this window
        window_pid = ctypes.wintypes.DWORD()
        ctypes.windll.user32.GetWindowThreadProcessId(hwnd, ctypes.byref(window_pid))

        if window_pid.value == pid:
            # Check if it's a visible main window
            if ctypes.windll.user32.IsWindowVisible(hwnd):
                # Get window title to filter out child windows
                length = ctypes.windll.user32.GetWindowTextLengthW(hwnd)
                if length > 0:
                    result.append(hwnd)
        return True

    WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.wintypes.HWND, ctypes.wintypes.LPARAM)
    ctypes.windll.user32.EnumWindows(WNDENUMPROC(enum_callback), 0)

    return result[0] if result else None


def get_window_rect(hwnd):
    """Get window position and size: returns (x, y, width, height) or None."""
    if not IS_WINDOWS or not hwnd:
        return None

    rect = ctypes.wintypes.RECT()
    if ctypes.windll.user32.GetWindowRect(hwnd, ctypes.byref(rect)):
        return {
            "x": rect.left,
            "y": rect.top,
            "width": rect.right - rect.left,
            "height": rect.bottom - rect.top,
        }
    return None


def set_window_rect(hwnd, x, y, width, height):
    """Set window position and size."""
    if not IS_WINDOWS or not hwnd:
        return False

    # SWP_NOZORDER = 0x0004 (don't change Z-order)
    # SWP_NOACTIVATE = 0x0010 (don't activate)
    SWP_NOZORDER = 0x0004
    SWP_NOACTIVATE = 0x0010
    return ctypes.windll.user32.SetWindowPos(
        hwnd, None, int(x), int(y), int(width), int(height),
        SWP_NOZORDER | SWP_NOACTIVATE
    )


# ============================================================================
# AUTO-INSTALL DEPENDENCIES
# ============================================================================

def ensure_deps():
    missing = []
    try:
        import psutil
    except ImportError:
        missing.append("psutil")
    try:
        from Crypto.Cipher import AES
    except ImportError:
        try:
            from Cryptodome.Cipher import AES
        except ImportError:
            missing.append("pycryptodome")

    if missing:
        print(f"[*] Installing: {', '.join(missing)}...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-q"] + missing)

ensure_deps()
import psutil


# ============================================================================
# CONFIGURATION
# ============================================================================

PORT = 8080
PLACE_ID = 133322550157181

# Profile-specific configurations
PROFILES = {
    "Unlock": {
        "default_servers": {
            "raid": {
                "name": "Raid Server",
                "place_id": 133322550157181,
                "link_code": "92098597466172680429134969286305",
                "server_id": 2704892549,
            },
        },
    },
    "Shake": {
        "default_servers": {
            "raid": {
                "name": "Raid Server",
                "place_id": 133322550157181,
                "link_code": "60273283948218585643111517071147",
                "server_id": 2895580141,
            },
        },
    },
}

# These will be set after profile selection
CURRENT_PROFILE = None
DATA_FILE = None
DEFAULT_SERVERS = {}
SERVERS = {}  # Loaded from data file at startup


def select_profile():
    """Show profile selection dialog and return selected profile name."""
    global CURRENT_PROFILE, DATA_FILE, DEFAULT_SERVERS

    # Create a simple selection dialog
    select_root = tk.Tk()
    select_root.title("Select Profile")
    select_root.configure(bg="#1a1a2e")
    select_root.resizable(False, False)

    # Center the window
    window_width = 300
    window_height = 280
    screen_width = select_root.winfo_screenwidth()
    screen_height = select_root.winfo_screenheight()
    x = (screen_width - window_width) // 2
    y = (screen_height - window_height) // 2
    select_root.geometry(f"{window_width}x{window_height}+{x}+{y}")

    selected = [None]  # Use list to allow modification in nested function

    tk.Label(
        select_root,
        text="Select Profile",
        font=("Segoe UI", 16, "bold"),
        fg="#e94560",
        bg="#1a1a2e"
    ).pack(pady=(20, 10))

    tk.Label(
        select_root,
        text="Choose which profile to load:",
        font=("Segoe UI", 10),
        fg="#aaaaaa",
        bg="#1a1a2e"
    ).pack(pady=(0, 15))

    button_frame = tk.Frame(select_root, bg="#1a1a2e")
    button_frame.pack(pady=10)

    def on_select(profile_name):
        selected[0] = profile_name
        select_root.destroy()

    for profile_name in PROFILES.keys():
        btn = tk.Button(
            button_frame,
            text=profile_name,
            font=("Segoe UI", 12, "bold"),
            fg="white",
            bg="#e94560",
            activebackground="#ff6b6b",
            activeforeground="white",
            width=15,
            height=2,
            cursor="hand2",
            command=lambda p=profile_name: on_select(p)
        )
        btn.pack(pady=5)

    # Handle window close
    def on_close():
        select_root.destroy()
        sys.exit(0)

    select_root.protocol("WM_DELETE_WINDOW", on_close)
    select_root.mainloop()

    if selected[0] is None:
        sys.exit(0)

    # Set global variables based on selection
    CURRENT_PROFILE = selected[0]
    base_dir = os.path.dirname(os.path.abspath(__file__))
    DATA_FILE = os.path.join(base_dir, f"roblox_manager_data_{CURRENT_PROFILE.lower()}.json")
    DEFAULT_SERVERS = PROFILES[CURRENT_PROFILE]["default_servers"]

    print(f"[+] Profile: {CURRENT_PROFILE}")
    print(f"[+] Data file: {DATA_FILE}")

    return CURRENT_PROFILE


def load_servers():
    """Load servers from data file, or use defaults.
    Merges link_code/server_id from DEFAULT_SERVERS into saved configs.
    Clears cached server_id if link_code was added or changed (forces re-resolve)."""
    global SERVERS
    if DATA_FILE and os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r") as f:
                data = json.load(f)
                saved = data.get("servers", {})
                if saved:
                    changed = False
                    for key, defaults in DEFAULT_SERVERS.items():
                        if key in saved:
                            # Sync link_code from defaults
                            if "link_code" in defaults:
                                old_lc = saved[key].get("link_code")
                                new_lc = defaults["link_code"]
                                if old_lc != new_lc:
                                    saved[key]["link_code"] = new_lc
                                    # link_code changed or added — cached server_id is stale
                                    if "server_id" in saved[key]:
                                        print(f"[CONFIG] {key}: link_code changed, clearing cached server_id={saved[key]['server_id']}")
                                        del saved[key]["server_id"]
                                    changed = True
                            # Merge server_id from defaults only if not already set
                            if "server_id" in defaults and "server_id" not in saved[key]:
                                saved[key]["server_id"] = defaults["server_id"]
                                changed = True
                        else:
                            saved[key] = dict(defaults)
                            changed = True
                    SERVERS = saved
                    if changed:
                        save_servers()
                    return
        except Exception:
            pass
    SERVERS = {k: dict(v) for k, v in DEFAULT_SERVERS.items()}
    save_servers()


def save_servers():
    """Save servers to data file."""
    try:
        data = {}
        if os.path.exists(DATA_FILE):
            with open(DATA_FILE, "r") as f:
                data = json.load(f)
        data["servers"] = SERVERS
        with open(DATA_FILE, "w") as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass


def save_ui_settings(settings):
    """Persist UI settings (watchdog, etc) to data file."""
    try:
        data = {}
        if os.path.exists(DATA_FILE):
            with open(DATA_FILE, "r") as f:
                data = json.load(f)
        data["ui_settings"] = settings
        with open(DATA_FILE, "w") as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass


def load_ui_settings():
    """Load saved UI settings from data file."""
    try:
        if os.path.exists(DATA_FILE):
            with open(DATA_FILE, "r") as f:
                data = json.load(f)
            return data.get("ui_settings", {})
    except Exception:
        pass
    return {}


def add_server(name, link_code, place_id=None, server_id=None, owner=None):
    """Add a new private server.

    Args:
        name: Display name for the server
        link_code: The privateServerLinkCode from the URL
        place_id: Optional place ID (defaults to PLACE_ID)
        server_id: Optional numeric privateServerId/vipServerId for shutdown (if not owned)
        owner: Optional account name that owns this server (used for shutdown requests)
    """
    key = name.lower().replace(" ", "_")
    SERVERS[key] = {
        "name": name,
        "place_id": place_id or PLACE_ID,
        "link_code": link_code,
    }
    if server_id:
        SERVERS[key]["server_id"] = server_id
    if owner:
        SERVERS[key]["owner"] = owner
    save_servers()
    return key


def remove_server(key):
    """Remove a server."""
    if key in SERVERS:
        del SERVERS[key]
        save_servers()
        return True
    return False


def extract_link_code(url_text):
    """Extract privateServerLinkCode from a Roblox URL.
    Supports:
      - https://www.roblox.com/games/123/Name?privateServerLinkCode=XXXX
      - Just the link code directly (digits only)
    """
    url_text = url_text.strip()
    # Direct link code (just digits)
    if url_text.isdigit() and len(url_text) > 10:
        return url_text
    # From privateServerLinkCode= parameter
    if "privateServerLinkCode=" in url_text:
        return url_text.split("privateServerLinkCode=")[1].split("&")[0].split("#")[0].strip()
    # From share URL - user needs to paste the redirected URL instead
    if "share?code=" in url_text:
        return None  # Can't auto-resolve; need the redirect
    return None


# ============================================================================
# THEME
# ============================================================================

class Theme:
    """Dynamic theme supporting light and dark modes."""
    _dark_mode = True  # Default to dark mode

    # These will be set by apply_mode()
    sidebar = ""
    sidebar_hover = ""
    sidebar_active = ""
    bg = ""
    bg_card = ""
    bg_card_hover = ""
    bg_input = ""
    primary = "#6366f1"
    primary_hover = "#4f46e5"
    primary_dim = "#312e81"
    accent = "#6366f1"
    accent_hover = "#4f46e5"
    accent_dim = "#312e81"
    green = "#22c55e"
    green_dim = "#166534"
    green_light = ""
    red = "#ef4444"
    red_dim = "#991b1b"
    red_light = ""
    blue = "#3b82f6"
    blue_dim = "#1e40af"
    blue_light = ""
    yellow = "#eab308"
    yellow_light = ""
    orange = "#f97316"
    orange_light = ""
    text = ""
    text_muted = ""
    text_dim = ""
    text_light = "#ffffff"
    border = ""
    border_dark = ""
    stat_purple = "#8b5cf6"
    stat_green = "#22c55e"
    stat_orange = "#f97316"
    stat_blue = "#3b82f6"
    # Title bar
    titlebar = ""
    titlebar_text = ""

    @classmethod
    def apply_mode(cls, dark=True):
        cls._dark_mode = dark
        if dark:
            # Dark mode
            cls.sidebar = "#1a1625"
            cls.sidebar_hover = "#2d2640"
            cls.sidebar_active = "#6366f1"
            cls.bg = "#0f0d13"
            cls.bg_card = "#1a1625"
            cls.bg_card_hover = "#252033"
            cls.bg_input = "#0f0d13"
            cls.text = "#e4e4e7"
            cls.text_muted = "#a1a1aa"
            cls.text_dim = "#71717a"
            cls.border = "#2d2640"
            cls.border_dark = "#3f3655"
            cls.green_light = "#166534"
            cls.red_light = "#7f1d1d"
            cls.blue_light = "#1e3a5f"
            cls.yellow_light = "#713f12"
            cls.orange_light = "#7c2d12"
            cls.titlebar = "#1a1625"
            cls.titlebar_text = "#e4e4e7"
        else:
            # Light mode
            cls.sidebar = "#1e1b4b"
            cls.sidebar_hover = "#312e81"
            cls.sidebar_active = "#4338ca"
            cls.bg = "#f8fafc"
            cls.bg_card = "#ffffff"
            cls.bg_card_hover = "#f1f5f9"
            cls.bg_input = "#f1f5f9"
            cls.text = "#1e293b"
            cls.text_muted = "#64748b"
            cls.text_dim = "#94a3b8"
            cls.border = "#e2e8f0"
            cls.border_dark = "#cbd5e1"
            cls.green_light = "#dcfce7"
            cls.red_light = "#fee2e2"
            cls.blue_light = "#dbeafe"
            cls.yellow_light = "#fef9c3"
            cls.orange_light = "#ffedd5"
            cls.titlebar = "#1e1b4b"
            cls.titlebar_text = "#ffffff"

    @classmethod
    def is_dark(cls):
        return cls._dark_mode

# Apply dark mode by default
Theme.apply_mode(dark=True)


# ============================================================================
# FLATUI TOGGLE SWITCH
# ============================================================================

class FlatToggle(tk.Canvas):
    """A modern flat toggle switch widget."""

    def __init__(self, parent, variable=None, command=None, text="", width=44, height=22,
                 bg=None, fg=None, on_color=None, off_color=None, **kwargs):
        self.width = width
        self.height = height
        self.bg_color = bg or Theme.bg_card
        self.fg_color = fg or Theme.text
        self.on_color = on_color or Theme.accent
        self.off_color = off_color or Theme.border_dark
        self.knob_color = "#ffffff"
        self.text = text
        self.command = command

        # Calculate total width including text
        total_width = width + (len(text) * 7 + 12 if text else 0)

        super().__init__(parent, width=total_width, height=height, bg=self.bg_color,
                        highlightthickness=0, cursor="hand2", **kwargs)

        # Variable binding
        if variable is None:
            self._variable = tk.BooleanVar(value=False)
        else:
            self._variable = variable

        # Draw elements
        self._draw()

        # Bindings
        self.bind("<Button-1>", self._on_click)
        self._variable.trace_add("write", lambda *args: self._update_visual())

    def _draw(self):
        """Draw the toggle switch."""
        self.delete("all")

        h = self.height
        w = self.width
        r = h // 2  # radius for rounded ends
        padding = 3
        knob_r = r - padding

        is_on = self._variable.get()
        track_color = self.on_color if is_on else self.off_color

        # Draw track (rounded rectangle)
        self.create_oval(0, 0, h, h, fill=track_color, outline="")
        self.create_oval(w - h, 0, w, h, fill=track_color, outline="")
        self.create_rectangle(r, 0, w - r, h, fill=track_color, outline="")

        # Draw knob
        knob_x = w - r if is_on else r
        self.create_oval(knob_x - knob_r, padding, knob_x + knob_r, h - padding,
                        fill=self.knob_color, outline="")

        # Draw text label
        if self.text:
            self.create_text(w + 8, h // 2, text=self.text, anchor="w",
                           font=("Segoe UI", 9), fill=self.fg_color)

    def _on_click(self, event):
        """Toggle the state on click."""
        self._variable.set(not self._variable.get())
        if self.command:
            self.command()

    def _update_visual(self):
        """Redraw when variable changes."""
        try:
            if self.winfo_exists():
                self._draw()
        except Exception:
            pass

    def get(self):
        return self._variable.get()

    def set(self, value):
        self._variable.set(value)


class FlatCheckbox(tk.Canvas):
    """A modern flat checkbox widget with rounded corners."""

    def __init__(self, parent, variable=None, command=None, text="", size=18,
                 bg=None, fg=None, check_color=None, **kwargs):
        self.size = size
        self.bg_color = bg or Theme.bg_card
        self.fg_color = fg or Theme.text
        self.check_color = check_color or Theme.accent
        self.border_color = Theme.border_dark
        self.text = text
        self.command = command

        # Calculate total width
        total_width = size + (len(text) * 7 + 10 if text else 0)

        super().__init__(parent, width=total_width, height=size, bg=self.bg_color,
                        highlightthickness=0, cursor="hand2", **kwargs)

        if variable is None:
            self._variable = tk.BooleanVar(value=False)
        else:
            self._variable = variable

        self._draw()
        self.bind("<Button-1>", self._on_click)
        self._variable.trace_add("write", lambda *args: self._update_visual())

    def _draw(self):
        """Draw the checkbox."""
        self.delete("all")

        s = self.size
        r = 4  # corner radius
        is_checked = self._variable.get()

        # Box background
        box_color = self.check_color if is_checked else self.bg_color
        border = "" if is_checked else self.border_color

        # Draw rounded rectangle
        self.create_polygon(
            r, 0, s - r, 0, s, r, s, s - r, s - r, s, r, s, 0, s - r, 0, r,
            fill=box_color, outline=border, width=1
        )

        # Draw checkmark if checked
        if is_checked:
            # Checkmark path
            cx, cy = s // 2, s // 2
            self.create_line(cx - 4, cy, cx - 1, cy + 3, fill="#fff", width=2, capstyle="round")
            self.create_line(cx - 1, cy + 3, cx + 5, cy - 3, fill="#fff", width=2, capstyle="round")

        # Draw text
        if self.text:
            self.create_text(s + 8, s // 2, text=self.text, anchor="w",
                           font=("Segoe UI", 9), fill=self.fg_color)

    def _on_click(self, event):
        self._variable.set(not self._variable.get())
        if self.command:
            self.command()

    def _update_visual(self):
        try:
            if self.winfo_exists():
                self._draw()
        except Exception:
            pass

    def get(self):
        return self._variable.get()

    def set(self, value):
        self._variable.set(value)


# ============================================================================
# WINDOWS HELPERS
# ============================================================================

if IS_WINDOWS:
    class DATA_BLOB(ctypes.Structure):
        _fields_ = [
            ("cbData", ctypes.wintypes.DWORD),
            ("pbData", ctypes.POINTER(ctypes.c_char)),
        ]

    def dpapi_decrypt(encrypted):
        blob_in = DATA_BLOB(len(encrypted), ctypes.create_string_buffer(encrypted, len(encrypted)))
        blob_out = DATA_BLOB()
        if ctypes.windll.crypt32.CryptUnprotectData(
            ctypes.byref(blob_in), None, None, None, None, 0, ctypes.byref(blob_out)
        ):
            result = ctypes.string_at(blob_out.pbData, blob_out.cbData)
            ctypes.windll.kernel32.LocalFree(blob_out.pbData)
            return result
        return None

    # ── Multi-Instance: Hold the singleton mutex/event BEFORE Roblox launches ──
    # Same approach as MultiBloxy, ic3w0lf22/ROBLOX_MULTI, Fishstrap/Bloxstrap.
    # Roblox checks for ROBLOX_singletonMutex and ROBLOX_singletonEvent.
    # If we own them first, Roblox can't claim exclusive access → multi-instance works.

    _held_handles = []  # Global list to keep handles alive for the lifetime of the manager

    def hold_mutex():
        """Create and hold Roblox singleton mutex/event so Roblox can't claim them.
        Must be called ONCE when the manager starts, before any Roblox launch."""
        kernel32 = ctypes.windll.kernel32

        # CreateMutexW(lpMutexAttributes, bInitialOwner, lpName)
        # bInitialOwner=True means we take ownership immediately
        for name in ["ROBLOX_singletonMutex"]:
            handle = kernel32.CreateMutexW(None, True, name)
            if handle:
                _held_handles.append(handle)
                print(f"[+] Holding mutex: {name} (handle={handle})")
            else:
                print(f"[-] Failed to create mutex: {name} (error={kernel32.GetLastError()})")

        # CreateEventW(lpEventAttributes, bManualReset, bInitialState, lpName)
        for name in ["ROBLOX_singletonEvent"]:
            handle = kernel32.CreateEventW(None, True, False, name)
            if handle:
                _held_handles.append(handle)
                print(f"[+] Holding event: {name} (handle={handle})")
            else:
                print(f"[-] Failed to create event: {name} (error={kernel32.GetLastError()})")

    def close_singleton_from_process(pid):
        """Close ROBLOX_singletonEvent handle inside a specific Roblox process.
        This is needed when a Roblox instance managed to create the event before us,
        or when we need to clean up a specific process's hold on it."""
        ntdll = ctypes.windll.ntdll
        kernel32 = ctypes.windll.kernel32

        class SYSTEM_HANDLE_TABLE_ENTRY_INFO(ctypes.Structure):
            _fields_ = [
                ("UniqueProcessId", ctypes.c_ushort),
                ("CreatorBackTraceIndex", ctypes.c_ushort),
                ("ObjectTypeIndex", ctypes.c_ubyte),
                ("HandleAttributes", ctypes.c_ubyte),
                ("HandleValue", ctypes.c_ushort),
                ("Object", ctypes.c_void_p),
                ("GrantedAccess", ctypes.c_ulong),
            ]

        buf_size = 0x10000
        while True:
            buf = ctypes.create_string_buffer(buf_size)
            ret_length = ctypes.c_ulong(0)
            status = ntdll.NtQuerySystemInformation(16, buf, buf_size, ctypes.byref(ret_length))
            if status == 0xC0000004:  # STATUS_INFO_LENGTH_MISMATCH
                buf_size *= 2
                continue
            break

        if status != 0:
            return 0

        handle_count = struct.unpack_from("I", buf.raw, 0)[0]
        offset = ctypes.sizeof(ctypes.c_ulong)
        entry_size = ctypes.sizeof(SYSTEM_HANDLE_TABLE_ENTRY_INFO)
        DUPLICATE_CLOSE_SOURCE = 0x00000001
        DUPLICATE_SAME_ACCESS = 0x00000002
        PROCESS_DUP_HANDLE = 0x0040
        HANDLE = ctypes.c_void_p
        closed = 0

        target_pids = {pid}

        for i in range(min(handle_count, 500000)):
            entry = SYSTEM_HANDLE_TABLE_ENTRY_INFO.from_buffer_copy(buf.raw, offset + i * entry_size)
            if entry.UniqueProcessId not in target_pids:
                continue
            # Mutex/Event type indices vary by Windows version, check a broad range
            if entry.ObjectTypeIndex not in range(15, 25):
                continue

            handle_val = entry.HandleValue
            proc_handle = kernel32.OpenProcess(PROCESS_DUP_HANDLE, False, entry.UniqueProcessId)
            if not proc_handle:
                continue

            dup_handle = HANDLE()
            status = ntdll.NtDuplicateObject(
                proc_handle, handle_val,
                kernel32.GetCurrentProcess(), ctypes.byref(dup_handle),
                0, 0, DUPLICATE_SAME_ACCESS,
            )

            if status != 0 or not dup_handle:
                kernel32.CloseHandle(proc_handle)
                continue

            buf2 = ctypes.create_string_buffer(1024)
            ret_len = ctypes.c_ulong(0)
            status = ntdll.NtQueryObject(dup_handle, 1, buf2, 1024, ctypes.byref(ret_len))
            kernel32.CloseHandle(dup_handle.value if isinstance(dup_handle, ctypes.c_void_p) else dup_handle)

            if status == 0 and ret_len.value > 0:
                try:
                    name_len = struct.unpack_from("H", buf2.raw, 0)[0]
                    if name_len > 0:
                        name_bytes = buf2.raw[8 : 8 + name_len]
                        name = name_bytes.decode("utf-16-le", errors="ignore")
                        if "ROBLOX_singleton" in name:
                            dup2 = HANDLE()
                            ntdll.NtDuplicateObject(
                                proc_handle, handle_val,
                                kernel32.GetCurrentProcess(), ctypes.byref(dup2),
                                0, 0, DUPLICATE_CLOSE_SOURCE,
                            )
                            if dup2:
                                kernel32.CloseHandle(dup2.value if isinstance(dup2, ctypes.c_void_p) else dup2)
                            closed += 1
                            print(f"[+] Closed singleton handle '{name}' from PID {entry.UniqueProcessId}")
                except Exception:
                    pass

            kernel32.CloseHandle(proc_handle)

        return closed

    def ensure_multi_instance():
        """Ensure multi-instance is possible: hold mutex + clean existing processes."""
        # First, hold the mutex ourselves
        hold_mutex()
        # Then close any existing Roblox singleton handles
        for proc in psutil.process_iter(["pid", "name"]):
            try:
                if proc.info["name"] and "RobloxPlayerBeta" in proc.info["name"]:
                    close_singleton_from_process(proc.info["pid"])
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue

else:
    def dpapi_decrypt(encrypted):
        return None
    def hold_mutex():
        pass
    def close_singleton_from_process(pid):
        return 0
    def ensure_multi_instance():
        pass


# ============================================================================
# CHROME COOKIE READER
# ============================================================================

def get_chrome_key():
    if not IS_WINDOWS:
        return None
    local_state_path = os.path.join(
        os.environ.get("LOCALAPPDATA", ""), r"Google\Chrome\User Data\Local State"
    )
    if not os.path.exists(local_state_path):
        return None
    with open(local_state_path, "r", encoding="utf-8") as f:
        local_state = json.load(f)
    encrypted_key = base64.b64decode(local_state["os_crypt"]["encrypted_key"])[5:]
    return dpapi_decrypt(encrypted_key)


def decrypt_chrome_cookie(encrypted_value, key):
    try:
        from Crypto.Cipher import AES
    except ImportError:
        from Cryptodome.Cipher import AES

    if encrypted_value[:3] in (b"v10", b"v20"):
        nonce = encrypted_value[3:15]
        ciphertext = encrypted_value[15:]
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        try:
            return cipher.decrypt_and_verify(ciphertext[:-16], ciphertext[-16:]).decode("utf-8")
        except Exception:
            return cipher.decrypt(ciphertext)[:-16].decode("utf-8", errors="ignore")

    result = dpapi_decrypt(encrypted_value)
    return result.decode("utf-8") if result else None


def get_cookie_from_chrome():
    if not IS_WINDOWS:
        return None
    local_app = os.environ.get("LOCALAPPDATA", "")
    cookie_paths = []
    chrome_ud = os.path.join(local_app, r"Google\Chrome\User Data")
    if os.path.exists(chrome_ud):
        for item in os.listdir(chrome_ud):
            if item == "Default" or item.startswith("Profile"):
                cookie_paths.append(os.path.join(chrome_ud, item, "Network", "Cookies"))
                cookie_paths.append(os.path.join(chrome_ud, item, "Cookies"))
    cookie_paths.append(os.path.join(local_app, r"Microsoft\Edge\User Data\Default\Network\Cookies"))

    key = get_chrome_key()
    if not key:
        return None

    for path in cookie_paths:
        if not os.path.exists(path):
            continue
        tmp = os.path.join(tempfile.gettempdir(), "rm_cookies_tmp.db")
        try:
            shutil.copy2(path, tmp)
            conn = sqlite3.connect(tmp)
            cursor = conn.cursor()
            cursor.execute(
                "SELECT encrypted_value FROM cookies WHERE host_key LIKE '%roblox.com' AND name = '.ROBLOSECURITY'"
            )
            row = cursor.fetchone()
            conn.close()
            if row and row[0]:
                decrypted = decrypt_chrome_cookie(row[0], key)
                if decrypted and len(decrypted) > 50:
                    return decrypted
        except Exception:
            continue
        finally:
            try:
                os.remove(tmp)
            except Exception:
                pass
    return None


# ============================================================================
# LOGIN VIA BROWSER - Opens Chrome with debug port, reads cookie via CDP
# ============================================================================

def find_chrome():
    """Find Chrome or Edge executable"""
    if not IS_WINDOWS:
        return None
    candidates = []
    for env in ["PROGRAMFILES", "PROGRAMFILES(X86)", "LOCALAPPDATA"]:
        base = os.environ.get(env, "")
        if base:
            candidates.append(os.path.join(base, r"Google\Chrome\Application\chrome.exe"))
            candidates.append(os.path.join(base, r"Microsoft\Edge\Application\msedge.exe"))
    for c in candidates:
        if os.path.exists(c):
            return c
    return None


def _ws_send(sock, message):
    """Send a WebSocket text frame"""
    import random as _rnd
    data = message.encode("utf-8")
    frame = bytearray()
    frame.append(0x81)
    length = len(data)
    if length < 126:
        frame.append(0x80 | length)
    elif length < 65536:
        frame.append(0x80 | 126)
        frame.extend(struct.pack(">H", length))
    else:
        frame.append(0x80 | 127)
        frame.extend(struct.pack(">Q", length))
    mask = _rnd.randbytes(4)
    frame.extend(mask)
    for i, byte in enumerate(data):
        frame.append(byte ^ mask[i % 4])
    sock.send(bytes(frame))


def _ws_recv(sock):
    """Receive a WebSocket text frame"""
    try:
        header = sock.recv(2)
        if len(header) < 2:
            return None
        masked = (header[1] & 0x80) != 0
        length = header[1] & 0x7F
        if length == 126:
            length = struct.unpack(">H", sock.recv(2))[0]
        elif length == 127:
            length = struct.unpack(">Q", sock.recv(8))[0]
        if masked:
            mask = sock.recv(4)
        payload = b""
        while len(payload) < length:
            chunk = sock.recv(min(4096, length - len(payload)))
            if not chunk:
                break
            payload += chunk
        if masked:
            payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        if (header[0] & 0x0F) == 0x1:
            return payload.decode("utf-8")
        return None
    except Exception:
        return None


def _cdp_get_cookie(debug_port):
    """Use Chrome DevTools Protocol to read .ROBLOSECURITY from running browser"""
    import socket as _sock
    import random as _rnd
    try:
        req = urllib.request.Request(f"http://127.0.0.1:{debug_port}/json")
        resp = urllib.request.urlopen(req, timeout=3)
        pages = json.loads(resp.read().decode())
        ws_url = None
        for page in pages:
            if "roblox.com" in page.get("url", "") and page.get("webSocketDebuggerUrl"):
                ws_url = page["webSocketDebuggerUrl"]
                break
        if not ws_url:
            return None

        ws_url_clean = ws_url.replace("ws://", "")
        host_port, path = ws_url_clean.split("/", 1)
        host, port = host_port.split(":")
        port = int(port)

        ws_key = base64.b64encode(_rnd.randbytes(16)).decode()
        s = _sock.socket(_sock.AF_INET, _sock.SOCK_STREAM)
        s.settimeout(5)
        s.connect((host, port))
        handshake = (
            f"GET /{path} HTTP/1.1\r\n"
            f"Host: {host}:{port}\r\n"
            f"Upgrade: websocket\r\nConnection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {ws_key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
        )
        s.send(handshake.encode())
        response = b""
        while b"\r\n\r\n" not in response:
            response += s.recv(4096)
        if b"101" not in response.split(b"\r\n")[0]:
            s.close()
            return None

        cmd = json.dumps({"id": 1, "method": "Network.getCookies", "params": {"urls": ["https://www.roblox.com"]}})
        _ws_send(s, cmd)
        data = _ws_recv(s)
        s.close()
        if not data:
            return None
        result = json.loads(data)
        for c in result.get("result", {}).get("cookies", []):
            if c.get("name") == ".ROBLOSECURITY" and len(c.get("value", "")) > 50:
                return c["value"]
    except Exception:
        pass
    return None


def login_via_browser(account_name, on_success, on_fail, on_status):
    """Open Chrome with temp profile + debug port, poll CDP for cookie after login"""
    chrome = find_chrome()
    if not chrome:
        on_fail("Chrome/Edge not found")
        return

    debug_port = 9222
    tmp_dir = os.path.join(tempfile.gettempdir(), f"rblx_login_{int(time.time())}")
    os.makedirs(tmp_dir, exist_ok=True)
    on_status("Opening browser - please log in to Roblox...")

    proc = subprocess.Popen([
        chrome, f"--user-data-dir={tmp_dir}", f"--remote-debugging-port={debug_port}",
        "--no-first-run", "--disable-default-apps", "--disable-extensions",
        "--disable-sync", "--new-window", "https://www.roblox.com/login"
    ])

    def poll_cookie():
        time.sleep(3)
        for _ in range(150):  # 5 min timeout (150 * 2s)
            if proc.poll() is not None:
                on_fail("Browser closed before login")
                shutil.rmtree(tmp_dir, ignore_errors=True)
                return
            cookie = _cdp_get_cookie(debug_port)
            if cookie:
                on_status("Cookie found! Closing browser...")
                try:
                    proc.terminate()
                    proc.wait(timeout=5)
                except Exception:
                    try: proc.kill()
                    except Exception: pass
                on_success(account_name, cookie)
                threading.Timer(3, lambda: shutil.rmtree(tmp_dir, ignore_errors=True)).start()
                return
            time.sleep(2)
        try: proc.terminate()
        except Exception: pass
        on_fail("Login timed out (5 min)")
        shutil.rmtree(tmp_dir, ignore_errors=True)

    threading.Thread(target=poll_cookie, daemon=True).start()


# ============================================================================
# ACCOUNT MANAGER (backend logic)
# ============================================================================

class AccountManager:
    def __init__(self):
        self.accounts = {}
        self.instances = {}
        # Player reports from Lua heartbeats: {reporter_username: {players, jobId, server, timestamp}}
        self.player_reports = {}
        # Restart cooldown: prevent concurrent restart requests
        self.last_restart_time = 0
        self.restart_cooldown = 30  # seconds
        self.load_data()

    def load_data(self):
        if DATA_FILE and os.path.exists(DATA_FILE):
            try:
                with open(DATA_FILE, "r") as f:
                    data = json.load(f)
                    self.accounts = data.get("accounts", {})
            except Exception:
                pass

    def save_data(self):
        try:
            data = {}
            if os.path.exists(DATA_FILE):
                with open(DATA_FILE, "r") as f:
                    data = json.load(f)
            data["accounts"] = self.accounts
            with open(DATA_FILE, "w") as f:
                json.dump(data, f, indent=2)
        except Exception:
            pass

    def add_account(self, name, cookie):
        user_info = self.verify_cookie(cookie)
        if user_info:
            self.accounts[name] = {
                "cookie": cookie,
                "user_id": user_info.get("id"),
                "username": user_info.get("name", "Unknown"),
                "display_name": user_info.get("displayName", "Unknown"),
            }
            self.save_data()
            return user_info
        return None

    def remove_account(self, name):
        if name in self.accounts:
            del self.accounts[name]
            self.save_data()
            return True
        return False

    def set_default_server(self, name, server_key):
        """Set the default server for an account. None or '' for public."""
        if name in self.accounts:
            self.accounts[name]["default_server"] = server_key or ""
            self.save_data()
            return True
        return False

    def get_default_server(self, name):
        """Get the default server key for an account."""
        if name in self.accounts:
            return self.accounts[name].get("default_server", "")
        return ""

    def set_priority(self, name, priority):
        """Set the launch priority for an account (lower = launches first)."""
        if name in self.accounts:
            self.accounts[name]["priority"] = priority
            self.save_data()
            return True
        return False

    def get_priority(self, name):
        """Get the launch priority for an account (default 100)."""
        if name in self.accounts:
            return self.accounts[name].get("priority", 100)
        return 100

    def get_accounts_by_priority(self, account_names=None):
        """Return account names sorted by priority (lowest first).
        If account_names is None, returns all accounts."""
        if account_names is None:
            account_names = list(self.accounts.keys())
        return sorted(account_names, key=lambda n: self.get_priority(n))

    def save_window_layout(self, name):
        """Save the current window position/size for an account's Roblox window."""
        if not IS_WINDOWS:
            return False

        inst = self.instances.get(name)
        if not inst or not inst.get("pid"):
            return False

        pid = inst["pid"]
        hwnd = get_window_by_pid(pid)
        if not hwnd:
            return False

        rect = get_window_rect(hwnd)
        if not rect:
            return False

        # Save to account data
        if name in self.accounts:
            self.accounts[name]["window_layout"] = rect
            self.save_data()
            print(f"[LAYOUT] {name}: saved window layout {rect['width']}x{rect['height']} at ({rect['x']}, {rect['y']})")
            return True
        return False

    def restore_window_layout(self, name, max_attempts=30):
        """Restore window position/size for an account's Roblox window.
        Polls rapidly for window to appear (every 0.3s, up to ~10 seconds total)."""
        if not IS_WINDOWS:
            return False

        acc = self.accounts.get(name)
        if not acc:
            return False

        layout = acc.get("window_layout")
        if not layout:
            return False  # No saved layout

        def do_restore():
            for attempt in range(max_attempts):
                time.sleep(0.3)  # Poll every 300ms for faster restore

                inst = self.instances.get(name)
                if not inst or not inst.get("pid"):
                    continue

                pid = inst["pid"]
                hwnd = get_window_by_pid(pid)
                if not hwnd:
                    continue

                # Found the window — restore its position/size
                if set_window_rect(hwnd, layout["x"], layout["y"], layout["width"], layout["height"]):
                    print(f"[LAYOUT] {name}: restored window layout {layout['width']}x{layout['height']} at ({layout['x']}, {layout['y']})")
                    return True

            print(f"[LAYOUT] {name}: could not restore layout (window not found after {max_attempts * 0.3:.1f}s)")
            return False

        threading.Thread(target=do_restore, daemon=True).start()
        return True

    def verify_cookie(self, cookie):
        ctx = ssl.create_default_context()
        req = urllib.request.Request(
            "https://users.roblox.com/v1/users/authenticated",
            headers={"Cookie": f".ROBLOSECURITY={cookie}"},
        )
        try:
            resp = urllib.request.urlopen(req, context=ctx, timeout=10)
            return json.loads(resp.read().decode())
        except Exception:
            return None

    def get_cookie(self, name):
        # Try exact match first
        acc = self.accounts.get(name)
        if acc:
            return acc["cookie"]
        # Fall back to case-insensitive match
        name_lower = name.lower()
        for acc_name, acc_data in self.accounts.items():
            if acc_name.lower() == name_lower:
                return acc_data["cookie"]
        return None

    def resolve_account_name(self, name):
        """Resolve account name with case-insensitive matching.
        Returns the actual stored name, or None if not found."""
        if name in self.accounts:
            return name
        name_lower = name.lower()
        for acc_name in self.accounts:
            if acc_name.lower() == name_lower:
                return acc_name
        return None

    def get_auth_ticket(self, cookie):
        csrf = self._get_csrf(cookie)
        if not csrf:
            return None
        ctx = ssl.create_default_context()
        req = urllib.request.Request(
            "https://auth.roblox.com/v1/authentication-ticket",
            method="POST",
            headers={
                "Cookie": f".ROBLOSECURITY={cookie}",
                "x-csrf-token": csrf,
                "Content-Type": "application/json",
                "Referer": "https://www.roblox.com/",
            },
            data=b"",
        )
        try:
            resp = urllib.request.urlopen(req, context=ctx, timeout=10)
            return resp.headers.get("rbx-authentication-ticket")
        except urllib.error.HTTPError as e:
            ticket = e.headers.get("rbx-authentication-ticket")
            return ticket if ticket else None
        except Exception:
            return None

    def _get_csrf(self, cookie):
        ctx = ssl.create_default_context()
        req = urllib.request.Request(
            "https://auth.roblox.com/v2/logout",
            method="POST",
            headers={"Cookie": f".ROBLOSECURITY={cookie}", "Content-Type": "application/json"},
            data=b"",
        )
        try:
            urllib.request.urlopen(req, context=ctx, timeout=10)
        except urllib.error.HTTPError as e:
            return e.headers.get("x-csrf-token")
        except Exception:
            pass
        return None

    def _roblox_post(self, cookie, url, body):
        print(f"[POST] Getting CSRF token...")
        csrf = self._get_csrf(cookie)
        if not csrf:
            return {"error": "Failed to get CSRF token"}
        print(f"[POST] CSRF: {csrf[:10]}...")
        ctx = ssl.create_default_context()
        data = json.dumps(body).encode("utf-8")
        print(f"[POST] Sending to {url}")
        print(f"[POST] Body: {data.decode()}")
        req = urllib.request.Request(
            url, method="POST",
            headers={
                "Cookie": f".ROBLOSECURITY={cookie}",
                "Content-Type": "application/json;charset=UTF-8",
                "x-csrf-token": csrf,
                "Origin": "https://www.roblox.com",
                "Referer": "https://www.roblox.com/",
            },
            data=data,
        )
        try:
            resp = urllib.request.urlopen(req, context=ctx, timeout=15)
            resp_body = resp.read().decode()
            print(f"[POST] Response: HTTP {resp.status}, body={resp_body[:200]}")
            try:
                parsed = json.loads(resp_body) if resp_body.strip() else {}
            except (json.JSONDecodeError, ValueError):
                parsed = resp_body
            return {"status": resp.status, "body": parsed}
        except urllib.error.HTTPError as e:
            body_text = ""
            try:
                body_text = e.read().decode() if e.fp else ""
            except Exception:
                pass
            print(f"[POST] HTTP Error: {e.code}, body={body_text[:200]}")
            return {"status": e.code, "body": body_text, "error": f"HTTP {e.code}"}
        except Exception as ex:
            print(f"[POST] Exception: {ex}")
            return {"error": str(ex)}

    def find_roblox_path(self):
        """Find RobloxPlayerBeta.exe using the same method as Roblox Account Manager:
        Query clientsettings.roblox.com for the current clientVersionUpload,
        then look for that exact version folder on disk."""
        if not IS_WINDOWS:
            return None

        # Step 1: Query Roblox API for the current version (same as RAM)
        api_version = None
        try:
            ctx = ssl.create_default_context()
            req = urllib.request.Request(
                "https://clientsettings.roblox.com/v1/client-version/WindowsPlayer",
                headers={"User-Agent": "Mozilla/5.0"},
            )
            resp = urllib.request.urlopen(req, context=ctx, timeout=10)
            data = json.loads(resp.read().decode())
            api_version = data.get("clientVersionUpload", "")  # e.g. "version-db4634f0e27d4d36"
        except Exception:
            pass

        versions_dirs = [
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions"),
            os.path.join(os.environ.get("PROGRAMFILES(X86)", ""), "Roblox", "Versions"),
            os.path.join(os.environ.get("PROGRAMFILES", ""), "Roblox", "Versions"),
        ]

        # Step 2: If we got a version from the API, use that exact folder
        if api_version:
            for versions_dir in versions_dirs:
                exe = os.path.join(versions_dir, api_version, "RobloxPlayerBeta.exe")
                if os.path.exists(exe):
                    return exe

        # Step 3: Fallback - pick the version folder with the newest directory mtime
        candidates = []
        for versions_dir in versions_dirs:
            if not os.path.exists(versions_dir):
                continue
            for vf in os.listdir(versions_dir):
                if not vf.startswith("version-"):
                    continue
                folder = os.path.join(versions_dir, vf)
                exe = os.path.join(folder, "RobloxPlayerBeta.exe")
                if os.path.exists(exe):
                    try:
                        mtime = os.path.getmtime(folder)
                        candidates.append((mtime, exe))
                    except OSError:
                        candidates.append((0, exe))
        if not candidates:
            return None
        candidates.sort(reverse=True)
        return candidates[0][1]

    def launch_instance(self, account_name, server_key=None, place_id=None, force=False):
        # Resolve account name (case-insensitive)
        resolved_name = self.resolve_account_name(account_name)
        if not resolved_name:
            available = list(self.accounts.keys())
            return {"error": f"Account '{account_name}' not found. Available: {available}"}
        account_name = resolved_name

        # ── DUPLICATE PREVENTION ──
        # Check if this account already has a running instance
        if not force:
            running, existing_pid, existing_server = self.get_instance_status(account_name, require_heartbeat=False)
            if running and existing_pid:
                # Verify process is actually alive
                try:
                    p = psutil.Process(existing_pid)
                    if p.is_running() and "RobloxPlayerBeta" in (p.name() or ""):
                        print(f"[LAUNCH] BLOCKED: {account_name} already running (PID {existing_pid}, server={existing_server})")
                        return {
                            "error": f"Already running",
                            "existing_pid": existing_pid,
                            "existing_server": existing_server,
                            "hint": "Use force=True to launch anyway (will cause logout)"
                        }
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    # Process is gone, clear the stale instance
                    print(f"[LAUNCH] Clearing stale instance for {account_name} (PID {existing_pid} no longer exists)")
                    self.instances.pop(account_name, None)

        cookie = self.get_cookie(account_name)
        if not cookie:
            return {"error": f"Account '{account_name}' has no cookie"}
        ticket = self.get_auth_ticket(cookie)
        if not ticket:
            return {"error": "Failed to get auth ticket"}

        place_id = place_id or PLACE_ID
        launch_time = int(time.time() * 1000)
        browser_tracker_id = str(random.randint(100000, 130000)) + str(random.randint(100000, 900000))

        if server_key and server_key in SERVERS:
            srv = SERVERS[server_key]
            link_code = srv.get("link_code", "")
            if not link_code:
                return {"error": f"No link_code for server '{server_key}'. Edit the server and add the privateServerLinkCode."}
            place_id = place_id or srv.get("place_id") or PLACE_ID
            # URL-encode the placelauncherurl the same way RAM does (HttpUtility.UrlEncode)
            place_launcher = urllib.parse.quote(
                f"https://assetgame.roblox.com/game/PlaceLauncher.ashx"
                f"?request=RequestPrivateGame&placeId={place_id}&accessCode=&linkCode={link_code}",
                safe="",
            )
            launch_url = (
                f"roblox-player:1+launchmode:play+gameinfo:{ticket}+launchtime:{launch_time}"
                f"+placelauncherurl:{place_launcher}"
                f"+browsertrackerid:{browser_tracker_id}+robloxLocale:en_us+gameLocale:en_us+channel:+LaunchExp:InApp"
            )
        else:
            place_launcher = urllib.parse.quote(
                f"https://assetgame.roblox.com/game/PlaceLauncher.ashx"
                f"?request=RequestGame&browserTrackerId={browser_tracker_id}&placeId={place_id}",
                safe="",
            )
            launch_url = (
                f"roblox-player:1+launchmode:play+gameinfo:{ticket}+launchtime:{launch_time}"
                f"+placelauncherurl:{place_launcher}"
                f"+browsertrackerid:{browser_tracker_id}+robloxLocale:en_us+gameLocale:en_us+channel:+LaunchExp:InApp"
            )

        # Clean any singleton handles from existing Roblox processes
        for p in psutil.process_iter(["pid", "name"]):
            try:
                if p.info["name"] and "RobloxPlayerBeta" in p.info["name"]:
                    close_singleton_from_process(p.info["pid"])
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        time.sleep(0.3)

        # Get PIDs of ALL currently running Roblox processes BEFORE we launch
        pids_before = set()
        for p in psutil.process_iter(["pid", "name"]):
            try:
                if p.info["name"] and "RobloxPlayerBeta" in p.info["name"]:
                    pids_before.add(p.info["pid"])
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

        try:
            # Launch via shell execute with roblox-player: protocol URI
            if IS_WINDOWS:
                os.startfile(launch_url)
            else:
                subprocess.Popen(["xdg-open", launch_url])

            # Store initial instance info with unique launch_id
            # The launch_id lets health check threads know if they're stale
            launch_id = f"{account_name}_{int(time.time() * 1000)}"
            self.instances[account_name] = {"pid": 0, "server_key": server_key, "launched_at": time.time(), "launch_id": launch_id}

            # Wait for new Roblox process to appear, then track its PID
            def track_real_pid():
                # Wait for Roblox to start (bootstrapper → actual game)
                for attempt in range(20):  # Try for up to 20 seconds
                    time.sleep(1)
                    # Find NEW Roblox processes that weren't running before
                    for p in psutil.process_iter(["pid", "name", "create_time"]):
                        try:
                            if (p.info["name"] and "RobloxPlayerBeta" in p.info["name"]
                                    and p.info["pid"] not in pids_before):
                                # Found a new process! Check if it's already tracked by another account
                                already_tracked = False
                                for other_name, other_inst in self.instances.items():
                                    if other_name != account_name and other_inst.get("pid") == p.info["pid"]:
                                        already_tracked = True
                                        break
                                if not already_tracked:
                                    self.instances[account_name]["pid"] = p.info["pid"]
                                    print(f"[PID] {account_name}: tracked PID {p.info['pid']}")
                                    close_singleton_from_process(p.info["pid"])
                                    # Add to pids_before so other concurrent launches don't grab it
                                    pids_before.add(p.info["pid"])
                                    # Restore saved window layout (runs in background)
                                    self.restore_window_layout(account_name)
                                    return
                        except (psutil.NoSuchProcess, psutil.AccessDenied):
                            continue
                print(f"[PID] {account_name}: could not find new Roblox process after 20s")

            threading.Thread(target=track_real_pid, daemon=True).start()

            # Launch health check: aggressive check after grace period
            # This catches Roblox stuck on "Loading... 100%" screen
            def launch_health_check():
                # Capture launch_id at start - if it changes, this thread is stale
                my_launch_id = launch_id
                acc_data = self.accounts.get(account_name, {})
                roblox_username = acc_data.get("username", "")

                # Phase 1: Wait for game to load + Lua to inject + boss loop to start
                # Heartbeat should arrive ~35-40s after launch
                time.sleep(45)

                inst = self.instances.get(account_name)
                if not inst:
                    return  # Instance was cleared (already handled)
                if inst.get("launch_id") != my_launch_id:
                    return  # Instance was relaunched, this health check is stale

                # Phase 2: Check every 3 seconds for 30 seconds (10 checks)
                # If 5 consecutive checks fail, kill and restart
                # Freshness window is 90s to catch any heartbeat since launch
                consecutive_failures = 0
                for check_num in range(10):
                    time.sleep(3)

                    inst = self.instances.get(account_name)
                    if not inst:
                        return  # Instance was cleared
                    if inst.get("launch_id") != my_launch_id:
                        return  # Instance was relaunched, this health check is stale

                    report = self.player_reports.get(roblox_username)
                    if report and (time.time() - report["timestamp"]) < 90:
                        # Got a heartbeat — we're good, exit health check
                        print(f"[HEALTH] {account_name}: heartbeat OK, fully loaded")
                        return
                    else:
                        consecutive_failures += 1
                        print(f"[HEALTH] {account_name}: no heartbeat (strike {consecutive_failures}/5, check {check_num + 1}/10)")

                        if consecutive_failures >= 5:
                            # 5 strikes — kill and restart
                            pid = inst.get("pid", 0)
                            if pid:
                                try:
                                    p = psutil.Process(pid)
                                    if p.is_running():
                                        p.kill()
                                        print(f"[HEALTH] {account_name}: killed hung process PID {pid} (5 consecutive heartbeat failures)")
                                except (psutil.NoSuchProcess, psutil.AccessDenied):
                                    pass
                            self.instances.pop(account_name, None)
                            if roblox_username and roblox_username in self.player_reports:
                                del self.player_reports[roblox_username]

                            # Queue restart after a short delay
                            time.sleep(2)
                            print(f"[HEALTH] {account_name}: restarting after health check failure...")
                            self.cleanup_orphan_processes()
                            restart_result = self.launch_instance(account_name, server_key)
                            if restart_result.get("success"):
                                print(f"[HEALTH] {account_name}: restarted successfully")
                            else:
                                print(f"[HEALTH] {account_name}: restart failed: {restart_result.get('error')}")
                            return

                # If we got here without a heartbeat after 75s total (45 + 30), kill the process
                inst = self.instances.get(account_name)
                if not inst:
                    return
                if inst.get("launch_id") != my_launch_id:
                    return  # Instance was relaunched, this health check is stale

                pid = inst.get("pid", 0)
                if pid:
                    try:
                        p = psutil.Process(pid)
                        if p.is_running():
                            p.kill()
                            print(f"[HEALTH] {account_name}: killed hung process PID {pid} (no heartbeat after 75s)")
                            self.instances.pop(account_name, None)
                            if roblox_username and roblox_username in self.player_reports:
                                del self.player_reports[roblox_username]
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        pass

            threading.Thread(target=launch_health_check, daemon=True).start()

            return {"success": True, "pid": 0, "account": account_name, "server": server_key}
        except Exception as e:
            return {"error": f"Launch failed: {e}"}

    def _find_new_roblox_pid(self, exclude_pids, after_timestamp=None):
        """Find a RobloxPlayerBeta PID that wasn't in the exclude set.
        If after_timestamp is provided, prefer processes created after that time."""
        candidates = []
        for p in psutil.process_iter(["pid", "name", "create_time"]):
            try:
                if (p.info["name"] and "RobloxPlayerBeta" in p.info["name"]
                        and p.info["pid"] not in exclude_pids):
                    candidates.append((p.info["pid"], p.info.get("create_time", 0)))
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        
        if not candidates:
            return None
        
        # If we have a timestamp, prefer processes created after it
        if after_timestamp:
            newer = [(pid, ct) for pid, ct in candidates if ct >= after_timestamp]
            if newer:
                # Return the NEWEST one (highest create_time)
                return max(newer, key=lambda x: x[1])[0]
        
        # Fallback: return first candidate
        return candidates[0][0]

    def _get_private_server_id(self, cookie, place_id, link_code=None, server_name=None):
        """Get the numeric privateServerId (vipServerId) from the private-servers API.
        API returns: vipServerId (numeric), accessCode (UUID), name, owner, etc.
        Tries to match by: accessCode, server name, or falls back to first owned."""
        try:
            ctx = ssl.create_default_context()
            url = f"https://games.roblox.com/v1/games/{place_id}/private-servers"
            req = urllib.request.Request(url, headers={
                "Cookie": f".ROBLOSECURITY={cookie}",
                "User-Agent": "Mozilla/5.0",
            })
            resp = urllib.request.urlopen(req, context=ctx, timeout=10)
            data = json.loads(resp.read().decode())
            servers = data.get("data", [])
            print(f"[DEBUG] private-servers returned {len(servers)} server(s)")
            for srv in servers:
                print(f"[DEBUG]   vipServerId={srv.get('vipServerId')}, name=\"{srv.get('name','?')}\", accessCode={str(srv.get('accessCode',''))[:12]}...")
            # 1) Match by link_code against accessCode
            if link_code:
                for srv in servers:
                    if srv.get("accessCode", "") == link_code:
                        print(f"[DEBUG] Matched by accessCode → vipServerId={srv.get('vipServerId')}")
                        return srv.get("vipServerId")
            # 2) Match by server name (case-insensitive partial match)
            if server_name:
                name_lower = server_name.lower()
                for srv in servers:
                    if name_lower in srv.get("name", "").lower():
                        print(f"[DEBUG] Matched by name \"{srv.get('name')}\" → vipServerId={srv.get('vipServerId')}")
                        return srv.get("vipServerId")
            # 3) If only one server, use it
            if len(servers) == 1:
                print(f"[DEBUG] Only one server → vipServerId={servers[0].get('vipServerId')}")
                return servers[0].get("vipServerId")
            # 4) Could not auto-match — return first one but warn
            if servers:
                vid = servers[0].get("vipServerId")
                print(f"[DEBUG] Could not auto-match, using first server → vipServerId={vid}")
                print(f"[DEBUG] TIP: Set 'server_id' in your server config to the correct vipServerId from the list above")
                return vid
        except Exception as ex:
            print(f"[DEBUG] private-servers error: {ex}")
        return None

    def shutdown_server(self, account_name, server_key, game_id=None):
        """Shutdown a private server. Matches the working boss_server.py approach:
        POST to matchmaking shutdown with placeId + privateServerId (numeric).
        gameId (jobId) is optional — sent if available from executor.
        If 404, re-resolves privateServerId from API and retries once.

        If the server has an 'owner' configured, use that account's cookie instead
        of trying random accounts (only the owner can shutdown their server)."""
        if server_key not in SERVERS:
            return {"error": f"Unknown server: {server_key}"}
        server = SERVERS[server_key]

        # Use owner account if specified, otherwise fall back to provided account or first account
        owner = server.get("owner")
        if owner and owner in self.accounts:
            account_name = owner
            print(f"[SHUTDOWN] Using owner account: {owner}")
        elif not account_name:
            account_name = next(iter(self.accounts), None)

        cookie = self.get_cookie(account_name)
        if not cookie:
            return {"error": f"No account '{account_name}' found"}
        srv_place_id = server.get("place_id") or PLACE_ID

        # Get numeric privateServerId — from cache or API
        ps_id = server.get("server_id")
        was_cached = ps_id is not None
        if not ps_id:
            ps_id = self._get_private_server_id(cookie, srv_place_id, server.get("link_code"), server.get("name"))
            if ps_id:
                server["server_id"] = ps_id
                save_servers()

        if not ps_id:
            return {"error": "Could not resolve privateServerId. Check server config."}

        # Build body
        body = {
            "placeId": srv_place_id,
            "privateServerId": ps_id,
        }
        if game_id:
            body["gameId"] = game_id

        print(f"[SHUTDOWN] {server.get('name',server_key)} → placeId={srv_place_id}, privateServerId={ps_id}, gameId={game_id or 'none'}")
        print(f"[SHUTDOWN] Sending POST to shutdown endpoint...")
        result = self._roblox_post(cookie, "https://apis.roblox.com/matchmaking-api/v1/game-instances/shutdown", body)
        print(f"[SHUTDOWN] Result: {result}")

        # If 404 and we used a cached server_id, the ID might be stale — re-resolve and retry
        if result.get("status") == 404 and was_cached:
            print(f"[SHUTDOWN] 404 with cached server_id={ps_id} — re-resolving from API...")
            server.pop("server_id", None)
            new_ps_id = self._get_private_server_id(cookie, srv_place_id, server.get("link_code"), server.get("name"))
            if new_ps_id and new_ps_id != ps_id:
                print(f"[SHUTDOWN] Resolved NEW server_id={new_ps_id} (was {ps_id}) — retrying shutdown...")
                server["server_id"] = new_ps_id
                save_servers()
                body["privateServerId"] = new_ps_id
                result = self._roblox_post(cookie, "https://apis.roblox.com/matchmaking-api/v1/game-instances/shutdown", body)
                print(f"[SHUTDOWN] Retry result: {result}")
            elif new_ps_id:
                print(f"[SHUTDOWN] Re-resolved same server_id={new_ps_id} — server likely has no active instance")
                server["server_id"] = new_ps_id
                save_servers()
            else:
                print(f"[SHUTDOWN] Could not re-resolve server_id from API")

        return result

    def restart_and_rejoin(self, account_name, server_key, game_id=None, delay=5):
        shutdown_result = self.shutdown_server(account_name, server_key, game_id)

        # Kill the process immediately so stale windows don't pile up
        instance = self.instances.get(account_name)
        if instance:
            try:
                p = psutil.Process(instance["pid"])
                if p.is_running():
                    # Save window layout before killing (so we can restore on relaunch)
                    self.save_window_layout(account_name)
                    p.kill()
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        self.instances.pop(account_name, None)

        def delayed_relaunch():
            time.sleep(delay)
            actual_srv = self.get_default_server(account_name) or server_key
            self.launch_instance(account_name, actual_srv)

        threading.Thread(target=delayed_relaunch, daemon=True).start()
        return {"shutdown": shutdown_result, "relaunch_in": delay, "account": account_name, "server": server_key}

    # ================================================================
    # PLAYER TRACKING (from Lua heartbeats)
    # ================================================================

    def process_heartbeat(self, data):
        """Process a heartbeat from a Lua executor.
        Data: {username, players: [...], jobId, server, placeId}
        Each account's Lua script sends this periodically so the manager
        knows which accounts are actually in-game and in which server."""
        username = data.get("username", "")
        players = data.get("players", [])
        job_id = data.get("jobId", "")
        server = data.get("server", "")

        print(f"[HEARTBEAT] Received from '{username}' in server '{server}' with {len(players)} players")

        self.player_reports[username] = {
            "players": players,
            "jobId": job_id,
            "server": server,
            "timestamp": time.time(),
        }
        return {"ok": True, "tracked": len(self.player_reports)}

    def get_server_players(self, server_key=None, max_age=60):
        """Get all known players across all reporting accounts.
        Returns: {server_key: {jobId, players: [...], reporters: [...], stale: bool}}
        If server_key specified, returns only that server's data."""
        now = time.time()
        servers = {}

        for reporter, report in self.player_reports.items():
            age = now - report["timestamp"]
            srv = report.get("server", "unknown")

            if server_key and srv != server_key:
                continue

            if srv not in servers:
                servers[srv] = {"players": set(), "reporters": [], "jobId": report["jobId"], "stale": False}

            for p in report["players"]:
                servers[srv]["players"].add(p)
            servers[srv]["reporters"].append(reporter)
            if age > max_age:
                servers[srv]["stale"] = True

        # Convert sets to sorted lists for JSON
        for srv in servers:
            servers[srv]["players"] = sorted(servers[srv]["players"])

        return servers

    def get_missing_accounts(self, server_key, max_age=60):
        """Check which managed accounts are NOT in the specified server.
        Compares account usernames against the latest player list from heartbeats.
        Returns: {present: [...], missing: [...], unknown: [...]}"""
        now = time.time()

        # Collect all players reported to be in this server
        in_server = set()
        have_report = False
        for reporter, report in self.player_reports.items():
            if report.get("server") == server_key and (now - report["timestamp"]) < max_age:
                have_report = True
                for p in report["players"]:
                    in_server.add(p.lower())

        if not have_report:
            return {"present": [], "missing": [], "unknown": list(self.accounts.keys()),
                    "error": "No recent heartbeats for this server"}

        present = []
        missing = []
        for acc_name, acc_data in self.accounts.items():
            username = acc_data.get("username", "").lower()
            display_name = acc_data.get("display_name", "").lower()
            if username in in_server or display_name in in_server:
                present.append(acc_name)
            else:
                missing.append(acc_name)

        return {"present": present, "missing": missing, "unknown": [],
                "players_in_server": sorted(in_server), "server": server_key}

    def get_instance_status(self, name, require_heartbeat=True):
        """Check if an account's Roblox instance is actually alive and in-game.
        Returns: (running, pid, server_key)
        If require_heartbeat=True (default): 'running' requires both process alive AND recent heartbeat
        If require_heartbeat=False: 'running' only requires process to be alive (for when Lua isn't loaded)"""
        inst = self.instances.get(name)
        if not inst:
            return False, None, None
        pid = inst.get("pid")
        srv = inst.get("server_key")

        # Check if process is alive
        process_alive = False
        try:
            p = psutil.Process(pid)
            process_alive = p.is_running()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass

        if not process_alive:
            return False, pid, srv

        # If we don't require heartbeat, just check process is alive
        if not require_heartbeat:
            return True, pid, srv

        # Process is alive — but is it actually in-game or stuck on disconnect screen?
        # Check heartbeat freshness: if Lua hasn't reported in, the client is likely dead
        account_data = self.accounts.get(name, {})
        roblox_username = account_data.get("username", "")
        report = self.player_reports.get(roblox_username)
        
        # Debug: show what we're looking for vs what we have
        # print(f"[STATUS] {name}: looking for heartbeat from '{roblox_username}', reports={list(self.player_reports.keys())}")
        
        if report:
            age = time.time() - report["timestamp"]
            if age < 60:  # Heartbeat within last 60s = definitely alive
                return True, pid, srv
            # Stale heartbeat = client probably disconnected but process still running
            return False, pid, srv

        # No heartbeat at all — check how long ago we launched
        launched_at = inst.get("launched_at", 0)
        age_since_launch = time.time() - launched_at
        if age_since_launch < 90:
            # Launched less than 90s ago — still loading, give it time
            return True, pid, srv

        # Process alive, no heartbeat, been a while since launch = stuck/disconnected
        return False, pid, srv

    def cleanup_orphan_processes(self, require_heartbeat=True):
        """Kill any RobloxPlayerBeta processes that aren't tracked by a healthy instance.

        This prevents zombie Roblox windows from piling up when:
        - PID tracking failed (pid=0) so we can't kill a specific process
        - Game got stuck on loading screen (no heartbeat ever sent)
        - Process survived a restart/rejoin cycle

        Args:
            require_heartbeat: If True, only processes with recent heartbeats are considered healthy.
                               If False, any running tracked process is considered healthy.

        Returns: number of orphan processes killed
        """
        # Collect PIDs that are tracked AND are considered healthy
        healthy_pids = set()
        for acc_name, inst in self.instances.items():
            pid = inst.get("pid", 0)
            if not pid:
                continue
            # Check if this instance is considered "running" (healthy)
            running, _, _ = self.get_instance_status(acc_name, require_heartbeat=require_heartbeat)
            if running:
                healthy_pids.add(pid)

        # Scan all Roblox processes and kill any that aren't healthy
        killed = 0
        for p in psutil.process_iter(["pid", "name"]):
            try:
                if p.info["name"] and "RobloxPlayerBeta" in p.info["name"]:
                    if p.info["pid"] not in healthy_pids:
                        p.kill()
                        killed += 1
                        print(f"[ORPHAN] Killed untracked/stale Roblox process PID {p.info['pid']}")
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

        # Also clean up instance entries with pid=0 (failed PID tracking)
        stale_instances = [name for name, inst in self.instances.items() if inst.get("pid", 0) == 0]
        for name in stale_instances:
            launched_at = self.instances[name].get("launched_at", 0)
            if time.time() - launched_at > 90:  # past grace period
                self.instances.pop(name, None)
                print(f"[ORPHAN] Cleared stale instance entry for {name} (pid=0, never tracked)")

        if killed:
            print(f"[ORPHAN] Cleanup done: killed {killed} orphan process(es)")
        return killed


# ============================================================================
# HTTP API SERVER (runs in background thread for executor)
# ============================================================================

manager = AccountManager()

# Note: load_servers() is called in main() after profile selection

# Hold the Roblox singleton mutex/event at startup so multi-instance always works
ensure_multi_instance()


class APIHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Content-Type", "application/json")

    def do_OPTIONS(self):
        self.send_response(200)
        self._cors()
        self.end_headers()

    def _respond(self, code, data):
        self.send_response(code)
        self._cors()
        self.end_headers()
        self.wfile.write(json.dumps(data, default=str).encode())

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode() if length > 0 else "{}"
        try:
            return json.loads(body)
        except Exception:
            return {}

    def do_GET(self):
        path = self.path.strip("/")
        parts = path.split("/")

        if path == "status":
            st = {}
            for n, a in manager.accounts.items():
                running, pid, srv = manager.get_instance_status(n)
                st[n] = {"username": a.get("username", "?"), "display_name": a.get("display_name", "?"),
                         "running": running, "pid": pid, "server": srv}
            players = manager.get_server_players()
            self._respond(200, {
                "status": "running", "accounts": st,
                "servers": {k: v["name"] for k, v in SERVERS.items()},
                "players": players,
                "heartbeats": len(manager.player_reports),
            })
            return
        if len(parts) == 2 and parts[0] == "shutdown":
            self._respond(200, manager.shutdown_server(None, parts[1]))
            return
        if len(parts) >= 2 and parts[0] in ("restart", "restart-no-rejoin"):
            server_key = parts[-1]
            self._respond(200, manager.shutdown_server(None, server_key))
            return
        if len(parts) >= 2 and parts[0] == "launch":
            self._respond(200, manager.launch_instance(parts[1], parts[2] if len(parts) > 2 else None))
            return
        if path == "kill-mutex":
            for p in psutil.process_iter(["pid", "name"]):
                try:
                    if p.info["name"] and "RobloxPlayerBeta" in p.info["name"]:
                        close_singleton_from_process(p.info["pid"])
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
            self._respond(200, {"status": "ok"})
            return

        # GET /players — all player reports from Lua heartbeats
        # GET /players/<server> — players in a specific server
        if parts[0] == "players":
            server_key = parts[1] if len(parts) >= 2 else None
            self._respond(200, manager.get_server_players(server_key))
            return

        # GET /missing/<server> — which managed accounts are NOT in this server
        if len(parts) >= 2 and parts[0] == "missing":
            self._respond(200, manager.get_missing_accounts(parts[1]))
            return

        # GET /my-server/<username> -- which server should this account use?
        # Lua calls this at boot to find out what server to enforce
        if len(parts) >= 2 and parts[0] == "my-server":
            username = parts[1]
            # Look up account by username (Lua sends LocalPlayer.Name)
            found_key = ""
            for acc_name, acc_data in manager.accounts.items():
                if acc_data.get("username", "").lower() == username.lower() or acc_name.lower() == username.lower():
                    found_key = manager.get_default_server(acc_name)
                    break
            # If no per-account default, use the global "Forced Server" setting from UI
            if not found_key:
                ui_settings = load_ui_settings()
                found_key = ui_settings.get("forcedServer", "farm")
            server_info = SERVERS.get(found_key, {})
            self._respond(200, {
                "server_key": found_key,
                "server_name": server_info.get("name", ""),
                "link_code": server_info.get("link_code", ""),
            })
            return

        # GET /verify-launch/<username> -- Lua asks "did you launch me recently?"
        # Used for server enforcement: if manager launched this account, trust it
        if len(parts) >= 2 and parts[0] == "verify-launch":
            username = parts[1]
            # Find account by username or account name
            found_acc = None
            for acc_name, acc_data in manager.accounts.items():
                if acc_data.get("username", "").lower() == username.lower() or acc_name.lower() == username.lower():
                    found_acc = acc_name
                    break
            if not found_acc:
                self._respond(200, {"ok": False, "reason": "unknown_account"})
                return
            inst = manager.instances.get(found_acc)
            if not inst:
                self._respond(200, {"ok": False, "reason": "no_instance"})
                return
            # Check if process is still alive
            pid_alive = False
            if inst.get("pid", 0):
                try:
                    pid_alive = psutil.pid_exists(inst["pid"])
                except:
                    pass
            launched_at = inst.get("launched_at", 0)
            age = time.time() - launched_at if launched_at else 9999
            server_key = inst.get("server_key", "")
            ui_settings = load_ui_settings()
            fallback_srv = ui_settings.get("forcedServer", "farm")
            expected = manager.get_default_server(found_acc) or fallback_srv
            self._respond(200, {
                "ok": pid_alive and server_key == expected,
                "pid_alive": pid_alive,
                "server_key": server_key,
                "expected_server": expected,
                "launched_ago": round(age),
                "account": found_acc,
            })
            return

        self._respond(200, {"info": "Roblox Manager API", "servers": list(SERVERS.keys())})

    def do_POST(self):
        path = self.path.strip("/")
        parts = path.split("/")
        data = self._read_body()
        game_id = data.get("gameId")
        delay = data.get("delay", 5)

        if path == "accounts":
            name, cookie = data.get("name"), data.get("cookie")
            if not name or not cookie:
                self._respond(400, {"error": "Need name and cookie"})
                return
            r = manager.add_account(name, cookie)
            self._respond(200 if r else 400, {"success": bool(r), "user": r} if r else {"error": "Invalid cookie"})
            return
        if path == "accounts/from-chrome":
            name = data.get("name", "main")
            cookie = get_cookie_from_chrome()
            if not cookie:
                self._respond(400, {"error": "No cookie in Chrome"})
                return
            r = manager.add_account(name, cookie)
            self._respond(200 if r else 400, {"success": bool(r), "user": r} if r else {"error": "Invalid cookie"})
            return

        # POST /heartbeat — Lua reports which players are in the server
        # Body: {username, players: [...], jobId, server}
        if path == "heartbeat":
            result = manager.process_heartbeat(data)
            # Also return missing accounts so Lua knows if anyone dropped
            server = data.get("server", "")
            missing_info = {}
            if server:
                missing_info = manager.get_missing_accounts(server)
            result["missing"] = missing_info.get("missing", [])
            result["present"] = missing_info.get("present", [])
            self._respond(200, result)
            return

        # POST /shutdown/<server> — shutdown only
        if len(parts) >= 2 and parts[0] == "shutdown":
            server_key = parts[1]
            account = data.get("account") or next(iter(manager.accounts), None)
            result = manager.shutdown_server(account, server_key, game_id)
            self._respond(200, {
                "shutdown": result,
                "server": SERVERS.get(server_key, {}).get("name", "unknown"),
                "gameId": game_id,
            })
            return

        # POST /restart/<server> — shutdown + relaunch ALL accounts into server
        # POST /restart/<account>/<server> — shutdown + relaunch specific account
        # Compatible with boss_server.py: Lua calls POST /restart/farm {gameId: "..."}
        # NOTE: Shutdown via Roblox API is best-effort — requires game owner's cookie.
        # Even if shutdown fails (404), the kill+relaunch still works because:
        # private servers shut down automatically ~30s after all players leave.
        if len(parts) >= 2 and parts[0] == "restart":
            server_key = parts[-1]  # last part is always the server
            specific_account = parts[1] if len(parts) >= 3 else None

            # ── COOLDOWN CHECK: Prevent concurrent restart requests ──
            # Multiple accounts might send restart at the same time when all bosses die
            now = time.time()
            time_since_last = now - manager.last_restart_time
            if time_since_last < manager.restart_cooldown:
                remaining = int(manager.restart_cooldown - time_since_last)
                print(f"[API] Restart {server_key}: SKIPPED (cooldown active, {remaining}s remaining)")
                self._respond(200, {
                    "skipped": True,
                    "reason": "restart_cooldown",
                    "cooldown_remaining": remaining,
                })
                return
            manager.last_restart_time = now

            # Attempt shutdown (best-effort — may 404 if not game owner)
            shutdown_acc = specific_account or next(iter(manager.accounts), None)
            shutdown_result = manager.shutdown_server(shutdown_acc, server_key, game_id)
            shutdown_ok = shutdown_result.get("status") == 200 or "error" not in shutdown_result
            if not shutdown_ok:
                print(f"[API] Restart {server_key}: shutdown failed (this is OK — will kill processes instead)")
                print(f"[API]   Private server will auto-close ~30s after all players leave")
            else:
                print(f"[API] Restart {server_key}: shutdown successful")

            # Figure out which accounts to relaunch
            if specific_account:
                relaunch_accounts = [specific_account]
            else:
                # Relaunch all accounts that had running instances
                relaunch_accounts = []
                for acc_name in manager.accounts:
                    running, pid, srv = manager.get_instance_status(acc_name)
                    if running or srv == server_key:
                        relaunch_accounts.append(acc_name)
                # Fallback: relaunch all accounts
                if not relaunch_accounts:
                    relaunch_accounts = list(manager.accounts.keys())

            # ── SAVE WINDOW LAYOUTS BEFORE KILLING ──
            for acc_name in relaunch_accounts:
                manager.save_window_layout(acc_name)

            # ── KILL ROBLOX PROCESSES ──
            killed = 0
            if specific_account:
                # Single-account restart: only kill THIS account's tracked PID
                inst = manager.instances.get(specific_account)
                target_pid = inst.get("pid", 0) if inst else 0
                if target_pid:
                    print(f"[RESTART] Killing only {specific_account}'s process (PID {target_pid})...")
                    try:
                        p = psutil.Process(target_pid)
                        p.kill()
                        killed = 1
                        print(f"[RESTART] Killed PID {target_pid} for {specific_account}")
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        print(f"[RESTART] PID {target_pid} already gone for {specific_account}")
                else:
                    print(f"[RESTART] No tracked PID for {specific_account}, skipping kill")
                manager.instances.pop(specific_account, None)
            else:
                # Full restart: kill ALL Roblox processes
                print(f"[RESTART] Killing all Roblox processes immediately...")
                for p in psutil.process_iter(["pid", "name"]):
                    try:
                        if p.info["name"] and "RobloxPlayerBeta" in p.info["name"]:
                            p.kill()
                            killed += 1
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        pass
                print(f"[RESTART] Killed {killed} Roblox process(es)")
                for acc_name in relaunch_accounts:
                    manager.instances.pop(acc_name, None)

            self._respond(200, {
                "shutdown": shutdown_result,
                "shutdown_ok": shutdown_ok,
                "killed": killed,
                "server": SERVERS.get(server_key, {}).get("name", "unknown"),
                "gameId": game_id,
                "relaunching": relaunch_accounts,
            })

            # Relaunch in background after delay, then verify all made it in
            # Capture variables for closure
            _relaunch_accounts = relaunch_accounts
            _server_key = server_key
            _delay = delay
            _shutdown_ok = shutdown_ok
            _specific_account = specific_account

            def delayed_relaunch():
                # Clear old heartbeats for accounts being relaunched
                for reporter in list(manager.player_reports.keys()):
                    if reporter in _relaunch_accounts:
                        del manager.player_reports[reporter]

                # Wait for private server to auto-close after all players left
                actual_delay = _delay if _shutdown_ok else max(_delay, 15)
                print(f"[RESTART] Waiting {actual_delay}s for server to clear (shutdown_ok={_shutdown_ok})...")
                time.sleep(actual_delay)

                if _specific_account:
                    # Single-account restart: only clean up that one account
                    # Don't touch other running instances
                    inst = manager.instances.get(_specific_account)
                    if inst and inst.get("pid"):
                        try:
                            p = psutil.Process(inst["pid"])
                            if p.is_running():
                                p.kill()
                                print(f"[RESTART] Final cleanup: killed {_specific_account}'s process")
                                time.sleep(1)
                        except (psutil.NoSuchProcess, psutil.AccessDenied):
                            pass
                    manager.instances.pop(_specific_account, None)
                else:
                    # Full restart: kill ALL remaining Roblox processes before relaunch
                    # This catches any that survived the initial kill or spawned during the delay
                    final_killed = 0
                    for p in psutil.process_iter(["pid", "name"]):
                        try:
                            if p.info["name"] and "RobloxPlayerBeta" in p.info["name"]:
                                p.kill()
                                final_killed += 1
                        except (psutil.NoSuchProcess, psutil.AccessDenied):
                            pass
                    if final_killed:
                        print(f"[RESTART] Final cleanup: killed {final_killed} remaining Roblox process(es)")
                        time.sleep(1)
                    # Clear all instance tracking to start fresh
                    manager.instances.clear()

                # Relaunch all accounts sorted by priority (lower = first)
                sorted_accounts = manager.get_accounts_by_priority(_relaunch_accounts)
                print(f"[RESTART] Launch order (by priority): {sorted_accounts}")
                for acc_name in sorted_accounts:
                    acc_server = manager.get_default_server(acc_name) or _server_key
                    result = manager.launch_instance(acc_name, acc_server)
                    print(f"[RESTART] Relaunched {acc_name} -> {acc_server}: {result}")
                    time.sleep(5)  # Stagger launches (5s to let autoexec complete)

                # Verify phase: wait for heartbeats then check who's missing
                print(f"[VERIFY] Waiting 45s for all accounts to join {_server_key}...")
                time.sleep(45)

                missing_info = manager.get_missing_accounts(_server_key, max_age=60)
                missing = missing_info.get("missing", [])
                present = missing_info.get("present", [])
                print(f"[VERIFY] {_server_key}: {len(present)} present, {len(missing)} missing")

                if missing:
                    print(f"[VERIFY] Missing accounts: {missing} — relaunching...")
                    for acc_name in missing:
                        # Kill stale process if any
                        inst = manager.instances.get(acc_name)
                        if inst and inst.get("pid"):
                            try:
                                p = psutil.Process(inst["pid"])
                                if p.is_running():
                                    p.kill()
                                    print(f"[VERIFY] Killed stale process PID {inst['pid']} for {acc_name}")
                                    time.sleep(0.5)
                            except (psutil.NoSuchProcess, psutil.AccessDenied):
                                pass
                        # Clear instance tracking so launch won't be blocked
                        manager.instances.pop(acc_name, None)
                        acc_server = manager.get_default_server(acc_name) or _server_key
                        result = manager.launch_instance(acc_name, acc_server)
                        print(f"[VERIFY] Re-relaunched {acc_name} -> {acc_server}: {result}")
                        time.sleep(5)  # 5s delay for autoexec
                else:
                    print(f"[VERIFY] All accounts confirmed in {_server_key}!")

            threading.Thread(target=delayed_relaunch, daemon=True).start()
            return

        # POST /launch/<account>/<server>
        if len(parts) >= 2 and parts[0] == "launch":
            self._respond(200, manager.launch_instance(parts[1], parts[2] if len(parts) > 2 else data.get("server")))
            return
        self._respond(404, {"error": "Unknown"})

    def do_DELETE(self):
        path = self.path.strip("/")
        parts = path.split("/")
        if len(parts) == 2 and parts[0] == "accounts":
            removed = manager.remove_account(parts[1])
            self._respond(200 if removed else 404,
                          {"removed": parts[1]} if removed else {"error": "not found"})
            return
        self._respond(404, {"error": "Unknown"})


def start_api_server():
    server = http.server.HTTPServer(("127.0.0.1", PORT), APIHandler)
    server.serve_forever()


# ============================================================================
# DESKTOP UI
# ============================================================================

class RobloxManagerApp:
    def __init__(self, root):
        self.root = root
        self.root.title(f"Roblox Manager - {CURRENT_PROFILE}")
        self.root.geometry("900x700")
        self.root.configure(bg=Theme.bg)
        self.root.resizable(True, True)
        self.root.minsize(800, 600)

        if IS_WINDOWS:
            try:
                self.root.update()
                hwnd = ctypes.windll.user32.GetParent(self.root.winfo_id())
                ctypes.windll.dwmapi.DwmSetWindowAttribute(
                    hwnd, 20, ctypes.byref(ctypes.c_int(1)), ctypes.sizeof(ctypes.c_int)
                )
            except Exception:
                pass

        self.logs = []
        self.auto_restart_job = None
        self.watchdog_accounts = {}  # {account_name: server_key} - accounts being watched

        # Load persisted settings (watchdog state, etc.)
        saved = load_ui_settings()
        self.settings = {
            "privateServerOnly": saved.get("privateServerOnly", False),
            "forcedServer": saved.get("forcedServer", "farm"),
            "autoRejoin": saved.get("autoRejoin", False),
            "autoRejoinInterval": saved.get("autoRejoinInterval", 30),
            "autoRejoinServer": saved.get("autoRejoinServer", "farm"),
            "watchdogAccounts": saved.get("watchdogAccounts", []),
        }

        self._build_ui()
        self._refresh_accounts()

        # Restore watchdog accounts from saved settings
        for acc_name in self.settings.get("watchdogAccounts", []):
            if acc_name in manager.accounts:
                self.watchdog_accounts[acc_name] = self.settings["autoRejoinServer"]

        # Apply saved settings to UI widgets (checkboxes, dropdowns, etc.)
        self._apply_persisted_settings_to_ui()

        # Start periodic stats refresh (every 2 seconds)
        self._start_stats_refresh()

        self.log("Manager started")
        self.log(f"API server on http://localhost:{PORT}")

    # ----------------------------------------------------------------
    # Logging
    # ----------------------------------------------------------------
    def log(self, text, level="info"):
        ts = datetime.now().strftime("%H:%M:%S")
        self.logs.append((ts, text, level))
        if len(self.logs) > 300:
            self.logs = self.logs[-200:]
        if hasattr(self, "log_text") and self.current_tab.get() == "logs":
            self._update_log_display()

    def _update_log_display(self):
        self.log_text.configure(state="normal")
        self.log_text.delete("1.0", "end")
        for ts, txt, lvl in self.logs[-100:]:
            self.log_text.insert("end", f"{ts}  ", "dim")
            self.log_text.insert("end", f"{txt}\n", lvl)
        self.log_text.configure(state="disabled")
        self.log_text.see("end")

    # ----------------------------------------------------------------
    # UI BUILD - Modern Sidebar Layout
    # ----------------------------------------------------------------
    def _build_ui(self):
        # Main container with sidebar
        main_container = tk.Frame(self.root, bg=Theme.bg)
        main_container.pack(fill="both", expand=True)

        # ═══════════════════════════════════════════════════════════════
        # SIDEBAR (Left)
        # ═══════════════════════════════════════════════════════════════
        sidebar = tk.Frame(main_container, bg=Theme.sidebar, width=180)
        sidebar.pack(side="left", fill="y")
        sidebar.pack_propagate(False)

        # Logo/Brand
        brand = tk.Frame(sidebar, bg=Theme.sidebar, pady=20)
        brand.pack(fill="x")
        tk.Label(brand, text="🎮", font=("Segoe UI Emoji", 24), bg=Theme.sidebar, fg=Theme.text_light).pack()
        tk.Label(brand, text="Roblox Manager", font=("Segoe UI", 12, "bold"), bg=Theme.sidebar, fg=Theme.text_light).pack()
        tk.Label(brand, text=CURRENT_PROFILE, font=("Segoe UI", 9), bg=Theme.sidebar, fg=Theme.text_dim).pack()

        # Separator
        tk.Frame(sidebar, bg=Theme.sidebar_hover, height=1).pack(fill="x", padx=20, pady=10)

        # Navigation
        self.current_tab = tk.StringVar(value="accounts")
        self.tab_btns = {}
        nav_items = [
            ("accounts", "👤", "Accounts"),
            ("servers", "🖥️", "Servers"),
            ("settings", "⚙️", "Settings"),
            ("logs", "📋", "Logs"),
        ]

        for key, icon, label in nav_items:
            btn_frame = tk.Frame(sidebar, bg=Theme.sidebar, cursor="hand2")
            btn_frame.pack(fill="x", padx=10, pady=2)

            btn = tk.Label(btn_frame, text=f"  {icon}  {label}", font=("Segoe UI", 10),
                          bg=Theme.sidebar, fg=Theme.text_light, anchor="w", padx=10, pady=8)
            btn.pack(fill="x")

            # Store reference
            self.tab_btns[key] = btn

            # Hover and click bindings
            def on_enter(e, f=btn_frame, b=btn):
                if self.current_tab.get() != [k for k, i, l in nav_items if l == b.cget("text").split("  ")[-1]][0]:
                    f.configure(bg=Theme.sidebar_hover)
                    b.configure(bg=Theme.sidebar_hover)

            def on_leave(e, f=btn_frame, b=btn):
                if self.current_tab.get() != [k for k, i, l in nav_items if l == b.cget("text").split("  ")[-1]][0]:
                    f.configure(bg=Theme.sidebar)
                    b.configure(bg=Theme.sidebar)

            def on_click(e, k=key):
                self._switch_tab(k)

            btn_frame.bind("<Enter>", on_enter)
            btn_frame.bind("<Leave>", on_leave)
            btn_frame.bind("<Button-1>", on_click)
            btn.bind("<Enter>", on_enter)
            btn.bind("<Leave>", on_leave)
            btn.bind("<Button-1>", on_click)

        # Spacer
        tk.Frame(sidebar, bg=Theme.sidebar).pack(fill="both", expand=True)

        # Status indicator at bottom of sidebar
        status_frame = tk.Frame(sidebar, bg=Theme.sidebar, pady=15)
        status_frame.pack(fill="x", side="bottom")
        self.status_lbl = tk.Label(status_frame, text="● ONLINE", font=("Segoe UI", 9, "bold"),
                                   bg=Theme.sidebar, fg=Theme.green)
        self.status_lbl.pack()

        # ═══════════════════════════════════════════════════════════════
        # MAIN CONTENT (Right)
        # ═══════════════════════════════════════════════════════════════
        right_panel = tk.Frame(main_container, bg=Theme.bg)
        right_panel.pack(side="right", fill="both", expand=True)

        # ─── Stats Cards Row ───
        stats_row = tk.Frame(right_panel, bg=Theme.bg, pady=15, padx=15)
        stats_row.pack(fill="x")

        self.stat_cards = {}
        stats_data = [
            ("accounts", "👤", "Accounts", "0", Theme.stat_purple),
            ("online", "🟢", "Online", "0", Theme.stat_green),
            ("heartbeats", "💓", "Heartbeats", "0", Theme.stat_orange),
            ("servers", "🖥️", "Servers", "0", Theme.stat_blue),
        ]

        for stat_key, icon, label, value, color in stats_data:
            card = tk.Frame(stats_row, bg=Theme.bg_card, padx=15, pady=12,
                           highlightbackground=Theme.border, highlightthickness=1)
            card.pack(side="left", expand=True, fill="x", padx=5)

            # Icon circle
            icon_lbl = tk.Label(card, text=icon, font=("Segoe UI Emoji", 16), bg=Theme.bg_card, fg=color)
            icon_lbl.pack(side="left", padx=(0, 10))

            # Text
            text_frame = tk.Frame(card, bg=Theme.bg_card)
            text_frame.pack(side="left", fill="x", expand=True)

            value_lbl = tk.Label(text_frame, text=value, font=("Segoe UI", 18, "bold"),
                                bg=Theme.bg_card, fg=Theme.text, anchor="w")
            value_lbl.pack(anchor="w")

            label_lbl = tk.Label(text_frame, text=label, font=("Segoe UI", 9),
                                bg=Theme.bg_card, fg=Theme.text_muted, anchor="w")
            label_lbl.pack(anchor="w")

            self.stat_cards[stat_key] = value_lbl

        # ─── Content Area ───
        self.content = tk.Frame(right_panel, bg=Theme.bg, padx=15, pady=5)
        self.content.pack(fill="both", expand=True)

        self.tab_frames = {}
        self._build_accounts_tab()
        self._build_servers_tab()
        self._build_settings_tab()
        self._build_logs_tab()

        # ─── Bottom Status Bar ───
        bot = tk.Frame(right_panel, bg=Theme.bg_card, padx=15, pady=8,
                      highlightbackground=Theme.border, highlightthickness=1)
        bot.pack(fill="x", side="bottom")
        self.bot_left = tk.Label(bot, text="0 accounts", font=("Consolas", 9), bg=Theme.bg_card, fg=Theme.text_dim)
        self.bot_left.pack(side="left")
        self.bot_right = tk.Label(bot, text="", font=("Consolas", 9), bg=Theme.bg_card, fg=Theme.accent)
        self.bot_right.pack(side="right")

        self._switch_tab("accounts")

    def _switch_tab(self, key):
        self.current_tab.set(key)
        # Update sidebar navigation highlighting
        for k, b in self.tab_btns.items():
            if k == key:
                b.configure(bg=Theme.sidebar_active, fg=Theme.text_light)
                b.master.configure(bg=Theme.sidebar_active)
            else:
                b.configure(bg=Theme.sidebar, fg=Theme.text_light)
                b.master.configure(bg=Theme.sidebar)
        # Switch content
        for c in self.content.winfo_children():
            c.pack_forget()
        self.tab_frames[key].pack(fill="both", expand=True)
        if key == "logs":
            self._update_log_display()
        elif key == "accounts":
            self._refresh_accounts()
        elif key == "servers":
            self._refresh_servers()
        # Update stats
        self._update_stats()

    def _update_stats(self):
        """Update the stats cards with current data."""
        if not hasattr(self, 'stat_cards'):
            return
        # Accounts count
        self.stat_cards["accounts"].configure(text=str(len(manager.accounts)))
        # Online count (running instances)
        online = sum(1 for name in manager.accounts if manager.get_instance_status(name, require_heartbeat=False)[0])
        self.stat_cards["online"].configure(text=str(online))
        # Heartbeats
        self.stat_cards["heartbeats"].configure(text=str(len(manager.player_reports)))
        # Servers count
        self.stat_cards["servers"].configure(text=str(len(SERVERS)))

    def _start_stats_refresh(self):
        """Start a periodic timer to refresh stats every 2 seconds."""
        def refresh_loop():
            try:
                self._update_stats()
            except Exception:
                pass
            # Schedule next refresh
            self.stats_refresh_job = self.root.after(2000, refresh_loop)
        refresh_loop()

    def _card(self, parent):
        return tk.Frame(parent, bg=Theme.bg_card, highlightbackground=Theme.border, highlightthickness=1, padx=12, pady=10)

    def _btn(self, parent, text, cmd, color=None, small=False):
        return tk.Button(parent, text=text, font=("Consolas", 9 if small else 10, "bold"),
                         bg=color or Theme.accent, fg="#fff", relief="flat", bd=0,
                         padx=10, pady=3 if small else 5,
                         activebackground=Theme.accent_hover, cursor="hand2", command=cmd)

    def _lbl(self, parent, text):
        return tk.Label(parent, text=text, font=("Consolas", 9, "bold"), bg=Theme.bg, fg=Theme.text_dim)

    # ----------------------------------------------------------------
    # ACCOUNTS TAB
    # ----------------------------------------------------------------
    def _build_accounts_tab(self):
        f = tk.Frame(self.content, bg=Theme.bg)
        self.tab_frames["accounts"] = f

        # Header row with label + select-all / deselect-all
        hdr = tk.Frame(f, bg=Theme.bg)
        hdr.pack(fill="x", pady=(0, 6))
        self._lbl(hdr, "ACCOUNTS").pack(side="left")
        self._btn(hdr, "Deselect All", self._deselect_all, color=Theme.accent_dim, small=True).pack(side="right", padx=(4, 0))
        self._btn(hdr, "Select All", self._select_all, color=Theme.blue_dim, small=True).pack(side="right")

        # Selection state: {account_name: BooleanVar}
        self.acc_selection = {}

        # Scrollable list
        canvas = tk.Canvas(f, bg=Theme.bg, highlightthickness=0)
        scrollbar = tk.Scrollbar(f, orient="vertical", command=canvas.yview)
        self.acc_inner = tk.Frame(canvas, bg=Theme.bg)
        self.acc_inner.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=self.acc_inner, anchor="nw", tags="inner")
        canvas.configure(yscrollcommand=scrollbar.set)

        def on_canvas_resize(e):
            canvas.itemconfig("inner", width=e.width)
        canvas.bind("<Configure>", on_canvas_resize)

        canvas.pack(side="top", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        # Launch Selected bar
        self.launch_bar = tk.Frame(f, bg=Theme.bg_card, padx=10, pady=6)
        self.launch_bar.pack(fill="x", pady=(6, 0))
        self.sel_count_label = tk.Label(self.launch_bar, text="0 selected", font=("Consolas", 10),
                                        bg=Theme.bg_card, fg=Theme.text_muted)
        self.sel_count_label.pack(side="left")
        self._btn(self.launch_bar, "\u25B6 Launch Selected", self._launch_selected, color=Theme.green_dim).pack(side="right")

        # Add section
        self._lbl(f, "ADD ACCOUNT").pack(anchor="w", pady=(10, 4))
        ac = self._card(f)
        ac.pack(fill="x")

        name_row = tk.Frame(ac, bg=Theme.bg_card)
        name_row.pack(fill="x", pady=(0, 6))
        tk.Label(name_row, text="Name:", font=("Consolas", 10), bg=Theme.bg_card, fg=Theme.text_muted).pack(side="left")
        self.e_name = tk.Entry(name_row, font=("Consolas", 10), bg=Theme.bg_input, fg=Theme.text,
                               insertbackground=Theme.text, relief="flat",
                               highlightbackground=Theme.border, highlightthickness=1)
        self.e_name.pack(side="left", fill="x", expand=True, padx=(8, 0))
        self.e_name.insert(0, "main")

        self.login_status = tk.Label(ac, text="", font=("Consolas", 9), bg=Theme.bg_card, fg=Theme.text_muted)
        self.login_status.pack(anchor="w")

        br = tk.Frame(ac, bg=Theme.bg_card)
        br.pack(fill="x", pady=(6, 0))
        self._btn(br, "\U0001F310 Login via Browser", self._login_browser, color=Theme.green_dim).pack(side="left", expand=True, fill="x", padx=(0, 3))
        self._btn(br, "\U0001F4CB Grab from Chrome", self._import_chrome, color=Theme.blue_dim).pack(side="left", expand=True, fill="x", padx=(3, 3))
        self._btn(br, "\U0001F4DD Paste Cookie", self._paste_cookie, color=Theme.accent_dim).pack(side="left", expand=True, fill="x", padx=(3, 0))

    def _refresh_accounts(self):
        for w in self.acc_inner.winfo_children():
            w.destroy()

        if not manager.accounts:
            tk.Label(self.acc_inner, text="No accounts yet", font=("Consolas", 10), bg=Theme.bg, fg=Theme.text_dim).pack(pady=20)
            self.acc_selection = {}
            self._update_sel_count()
            self._update_bottom()
            return

        # Sync selection vars: keep existing, add new, remove stale
        old_sel = self.acc_selection if hasattr(self, 'acc_selection') else {}
        new_sel = {}
        for name in manager.accounts:
            if name in old_sel:
                new_sel[name] = old_sel[name]
            else:
                new_sel[name] = tk.BooleanVar(value=False)
        self.acc_selection = new_sel

        # Sort accounts by priority for display
        sorted_accounts = manager.get_accounts_by_priority(list(manager.accounts.keys()))

        for name in sorted_accounts:
            acc = manager.accounts[name]
            running, pid, srv = manager.get_instance_status(name)
            default_srv = manager.get_default_server(name)
            priority = manager.get_priority(name)
            c = self._card(self.acc_inner)
            c.pack(fill="x", pady=(0, 6), padx=(0, 12))

            # Checkbox on far left
            cb = FlatCheckbox(c, variable=self.acc_selection[name],
                              command=self._update_sel_count, bg=Theme.bg_card)
            cb.pack(side="left", padx=(0, 8))

            left = tk.Frame(c, bg=Theme.bg_card)
            left.pack(side="left", fill="x", expand=True)

            icon_col = Theme.green if running else Theme.text
            # Show priority badge if not default
            priority_badge = f"[#{priority}] " if priority != 100 else ""
            tk.Label(left, text=f"{'🟢' if running else '👤'}  {priority_badge}{name}", font=("Consolas", 11, "bold"),
                     bg=Theme.bg_card, fg=icon_col).pack(anchor="w")

            det = f"{acc.get('username', '?')} \u00b7 {acc.get('display_name', '?')}"
            if running and pid:
                det += f" \u00b7 PID {pid}"
            # Show assigned server
            if default_srv and default_srv in SERVERS:
                det += f" \u00b7 \U0001F4E1 {SERVERS[default_srv]['name']}"
            elif default_srv == "":
                det += f" \u00b7 \U0001F310 Public"
            if running and srv:
                det += f" \u00b7 on {srv}"
            tk.Label(left, text=det, font=("Consolas", 9), bg=Theme.bg_card, fg=Theme.text_muted).pack(anchor="w")

            right = tk.Frame(c, bg=Theme.bg_card)
            right.pack(side="right")
            self._btn(right, "\u25B6", lambda n=name: self._quick_launch(n), color=Theme.green_dim, small=True).pack(side="left", padx=2)
            self._btn(right, "\u270F", lambda n=name: self._edit_account(n), color=Theme.blue_dim, small=True).pack(side="left", padx=2)
            self._btn(right, "\u2715", lambda n=name: self._remove_acc(n), color=Theme.red_dim, small=True).pack(side="left", padx=2)

        self._update_sel_count()
        self._update_bottom()

    def _update_sel_count(self):
        """Update the 'X selected' label in the launch bar."""
        if not hasattr(self, 'sel_count_label'):
            return
        n = sum(1 for v in self.acc_selection.values() if v.get())
        self.sel_count_label.configure(text=f"{n} selected")

    def _select_all(self):
        for v in self.acc_selection.values():
            v.set(True)
        self._update_sel_count()

    def _deselect_all(self):
        for v in self.acc_selection.values():
            v.set(False)
        self._update_sel_count()

    def _get_selected_accounts(self):
        """Return list of selected account names."""
        return [name for name, var in self.acc_selection.items() if var.get()]

    def _launch_selected(self):
        """Launch all selected accounts sequentially with 5s delay between each."""
        selected = self._get_selected_accounts()
        if not selected:
            self.log("No accounts selected", "warn")
            return

        # Sort by priority (lower = first)
        selected = manager.get_accounts_by_priority(selected)
        total = len(selected)
        self.log(f"Launching {total} account{'s' if total != 1 else ''} by priority (5s between each)...")

        def do_launches():
            for i, name in enumerate(selected):
                default_srv = manager.get_default_server(name)
                srv = default_srv if default_srv and default_srv in SERVERS else None
                label = SERVERS[srv]["name"] if srv else "public"

                self.root.after(0, lambda n=name, l=label, idx=i: self.log(f"[{idx+1}/{total}] Launching {n} → {l}..."))

                r = manager.launch_instance(name, srv)
                if r.get("success"):
                    self.root.after(0, lambda n=name, pid=r['pid']: self.log(f"✔ {n} launched (PID {pid})", "success"))
                else:
                    err = r.get('error', '?')
                    self.root.after(0, lambda n=name, e=err: self.log(f"✘ {n} failed: {e}", "error"))

                # Wait 5s before launching next account (except after last one)
                if i < total - 1:
                    time.sleep(5)

            self.root.after(0, lambda: self.log(f"Launch complete ({total} accounts)", "success"))
            self.root.after(500, self._refresh_accounts)

        threading.Thread(target=do_launches, daemon=True).start()

    def _login_browser(self):
        if getattr(self, '_login_pending', False):
            self.log("Login already in progress", "warn")
            return
        name = self.e_name.get().strip() or "main"
        self._login_pending = True
        self.login_status.configure(text="\u23F3 Opening browser...", fg=Theme.yellow)
        self.log(f"Login via browser for '{name}'...")

        def on_success(acc_name, cookie):
            self._login_pending = False
            self.root.after(0, lambda: self.login_status.configure(text="\u23F3 Verifying cookie...", fg=Theme.yellow))
            result = manager.add_account(acc_name, cookie)
            def done():
                if result:
                    self.login_status.configure(text=f"\u2714 Logged in as {result.get('name', '?')}", fg=Theme.green)
                    self.log(f"Added: {result.get('name', '?')} ({result.get('displayName', '?')})", "success")
                else:
                    self.login_status.configure(text="\u2718 Cookie invalid", fg=Theme.red)
                    self.log("Cookie grabbed but verification failed", "error")
                self._refresh_accounts()
            self.root.after(0, done)

        def on_fail(msg):
            self._login_pending = False
            self.root.after(0, lambda: self.login_status.configure(text=f"\u2718 {msg}", fg=Theme.red))
            self.root.after(0, lambda: self.log(f"Login failed: {msg}", "error"))

        def on_status(msg):
            self.root.after(0, lambda: self.login_status.configure(text=f"\u23F3 {msg}", fg=Theme.yellow))

        login_via_browser(name, on_success, on_fail, on_status)

    def _import_chrome(self):
        name = self.e_name.get().strip() or "main"
        self.login_status.configure(text="\u23F3 Reading Chrome cookies...", fg=Theme.yellow)
        self.log(f"Reading Chrome cookie for '{name}'...")

        def do():
            cookie = get_cookie_from_chrome()
            if not cookie:
                self.root.after(0, lambda: self.login_status.configure(text="\u2718 No cookie in Chrome", fg=Theme.red))
                self.root.after(0, lambda: self.log("No cookie in Chrome", "error"))
                return
            r = manager.add_account(name, cookie)
            self.root.after(0, lambda: self._on_added(name, r))
        threading.Thread(target=do, daemon=True).start()

    def _paste_cookie(self):
        cookie = simpledialog.askstring("Paste Cookie", "Paste your .ROBLOSECURITY cookie:", show="\u2022")
        if not cookie:
            return
        name = self.e_name.get().strip() or "main"
        self.login_status.configure(text="\u23F3 Verifying...", fg=Theme.yellow)
        self.log(f"Adding {name} from pasted cookie...")

        def do():
            r = manager.add_account(name, cookie.strip())
            self.root.after(0, lambda: self._on_added(name, r))
        threading.Thread(target=do, daemon=True).start()

    def _on_added(self, name, result):
        if result:
            self.login_status.configure(text=f"\u2714 Added {result.get('name', '?')}", fg=Theme.green)
            self.log(f"Added: {result.get('name', '?')} ({result.get('displayName', '?')})", "success")
        else:
            self.log(f"Failed to add '{name}' - invalid cookie", "error")
        self._refresh_accounts()

    def _remove_acc(self, name):
        if messagebox.askyesno("Remove", f'Remove "{name}"?'):
            manager.remove_account(name)
            self.log(f"Removed: {name}", "warn")
            self._refresh_accounts()

    def _quick_launch(self, name):
        """Launch with the account's assigned default server (no dialog)."""
        default_srv = manager.get_default_server(name)
        srv = default_srv if default_srv and default_srv in SERVERS else None
        label = SERVERS[srv]["name"] if srv else "public"
        self.log(f"Launching {name} \u2192 {label}...")

        def do():
            r = manager.launch_instance(name, srv)
            msg = f"Launched! PID: {r['pid']}" if r.get("success") else f"Failed: {r.get('error', '?')}"
            lvl = "success" if r.get("success") else "error"
            self.root.after(0, lambda: self.log(msg, lvl))
            self.root.after(800, self._refresh_accounts)
        threading.Thread(target=do, daemon=True).start()

    def _edit_account(self, name):
        """Dialog to edit account settings (server, priority)."""
        acc = manager.accounts.get(name)
        if not acc:
            return

        dlg = tk.Toplevel(self.root)
        dlg.title(f"Edit: {name}")
        dlg.configure(bg=Theme.bg)
        dlg.geometry("350x260")
        dlg.transient(self.root)
        dlg.grab_set()

        pad = {"padx": 12, "pady": (8, 0)}

        # Account info
        tk.Label(dlg, text=f"{acc.get('username', '?')} ({acc.get('display_name', '?')})",
                 font=("Consolas", 10, "bold"), bg=Theme.bg, fg=Theme.text).pack(anchor="w", **pad)

        # Priority
        tk.Label(dlg, text="Launch Priority (lower = first):", font=("Consolas", 10),
                 bg=Theme.bg, fg=Theme.text).pack(anchor="w", **pad)
        tk.Label(dlg, text="Use 1 for first, 2 for second, etc. Default is 100.",
                 font=("Consolas", 8), bg=Theme.bg, fg=Theme.text_dim).pack(anchor="w", padx=12)

        priority_var = tk.StringVar(value=str(manager.get_priority(name)))
        priority_entry = tk.Entry(dlg, textvariable=priority_var, font=("Consolas", 10),
                                   bg=Theme.bg_card, fg=Theme.text, insertbackground=Theme.text,
                                   relief="flat", bd=0, width=10)
        priority_entry.pack(anchor="w", padx=12, pady=(2, 0), ipady=4)

        # Default server
        tk.Label(dlg, text="Default Server:", font=("Consolas", 10),
                 bg=Theme.bg, fg=Theme.text).pack(anchor="w", **pad)

        current_srv = manager.get_default_server(name)
        server_options = ["(Public)"] + [SERVERS[k]["name"] for k in SERVERS]
        server_keys = [""] + list(SERVERS.keys())

        server_var = tk.StringVar()
        if current_srv and current_srv in SERVERS:
            server_var.set(SERVERS[current_srv]["name"])
        else:
            server_var.set("(Public)")

        server_menu = ttk.Combobox(dlg, textvariable=server_var, values=server_options,
                                    state="readonly", font=("Consolas", 10))
        server_menu.pack(anchor="w", padx=12, pady=(2, 0), ipady=2)

        status = tk.Label(dlg, text="", font=("Consolas", 9), bg=Theme.bg, fg=Theme.accent)
        status.pack(anchor="w", padx=12, pady=(8, 0))

        def do_save():
            # Save priority
            try:
                new_priority = int(priority_var.get().strip())
                manager.set_priority(name, new_priority)
            except ValueError:
                status.config(text="Priority must be a number", fg="#ff4444")
                return

            # Save server
            selected_name = server_var.get()
            new_srv = ""
            for i, opt in enumerate(server_options):
                if opt == selected_name:
                    new_srv = server_keys[i]
                    break
            manager.set_default_server(name, new_srv)

            status.config(text="Saved!", fg=Theme.green)
            self.root.after(500, lambda: [dlg.destroy(), self._refresh_accounts()])

        btn_frame = tk.Frame(dlg, bg=Theme.bg)
        btn_frame.pack(fill="x", padx=12, pady=(12, 12))
        self._btn(btn_frame, "Save", do_save, color=Theme.green_dim).pack(side="right")
        self._btn(btn_frame, "Cancel", dlg.destroy).pack(side="right", padx=(0, 8))
        self._btn(btn_frame, "Remove", lambda: [dlg.destroy(), self._remove_acc(name)],
                  color=Theme.red_dim).pack(side="left")

    def _set_server(self, name, server_key):
        """Assign a default server to an account."""
        manager.set_default_server(name, server_key)
        label = SERVERS[server_key]["name"] if server_key and server_key in SERVERS else "Public"
        self.log(f"{name} \u2192 {label}", "success")
        self._refresh_accounts()

    def _launch_dlg(self, name):
        """Legacy launch dialog — kept for server tab usage."""
        opts = list(SERVERS.keys())
        choice = simpledialog.askstring("Launch", f"Server for '{name}'?\n({', '.join(opts)} or empty for public)", initialvalue="farm")
        if choice is None:
            return
        srv = choice if choice in SERVERS else None
        self.log(f"Launching {name} \u2192 {srv or 'public'}...")

        def do():
            r = manager.launch_instance(name, srv)
            msg = f"Launched! PID: {r['pid']}" if r.get("success") else f"Failed: {r.get('error', '?')}"
            lvl = "success" if r.get("success") else "error"
            self.root.after(0, lambda: self.log(msg, lvl))
            self.root.after(800, self._refresh_accounts)
        threading.Thread(target=do, daemon=True).start()

    # ----------------------------------------------------------------
    # SERVERS TAB
    # ----------------------------------------------------------------
    def _build_servers_tab(self):
        f = tk.Frame(self.content, bg=Theme.bg)
        self.tab_frames["servers"] = f

        # Header row
        hdr = tk.Frame(f, bg=Theme.bg)
        hdr.pack(fill="x", pady=(0, 6))
        self._lbl(hdr, "PRIVATE SERVERS").pack(side="left")
        self._btn(hdr, "+ Add Server", self._do_add_server, color=Theme.green_dim, small=True).pack(side="right")

        self.srv_inner = tk.Frame(f, bg=Theme.bg)
        self.srv_inner.pack(fill="both", expand=True)

        tk.Frame(f, bg=Theme.border, height=1).pack(fill="x", pady=(10, 6))
        mr = tk.Frame(f, bg=Theme.bg)
        mr.pack(fill="x")
        tk.Label(mr, text="\U0001F513 Multi-Instance \u2014 mutex held automatically", font=("Consolas", 9), bg=Theme.bg, fg=Theme.text_muted).pack(side="left")
        self._btn(mr, "Kill All & Reset", self._do_kill_all_reset, color="#8b0000", small=True).pack(side="right", padx=(4, 0))
        self._btn(mr, "Clean Handles", self._do_kill_mutex, color=Theme.blue_dim, small=True).pack(side="right")

    def _refresh_servers(self):
        for w in self.srv_inner.winfo_children():
            w.destroy()

        if not SERVERS:
            tk.Label(self.srv_inner, text="No servers added. Click '+ Add Server' to add one.",
                     font=("Consolas", 10), bg=Theme.bg, fg=Theme.text_dim).pack(pady=20)
            return

        for key, srv in SERVERS.items():
            c = self._card(self.srv_inner)
            c.pack(fill="x", pady=(0, 6))

            top = tk.Frame(c, bg=Theme.bg_card)
            top.pack(fill="x")
            tk.Label(top, text=f"\U0001F5A5  {srv['name']}", font=("Consolas", 11, "bold"), bg=Theme.bg_card, fg=Theme.text).pack(side="left")

            btns = tk.Frame(top, bg=Theme.bg_card)
            btns.pack(side="right")
            self._btn(btns, "\U0001F5D1", lambda k=key: self._do_remove_server(k), color="#6b2020", small=True).pack(side="left", padx=2)
            self._btn(btns, "\u270F Edit", lambda k=key: self._do_edit_server(k), color=Theme.blue_dim, small=True).pack(side="left", padx=2)
            self._btn(btns, "\u23F9 Shutdown", lambda k=key: self._do_shutdown(k), small=True).pack(side="left", padx=2)
            self._btn(btns, "\u25B6 Launch", lambda k=key: self._do_srv_launch(k), color=Theme.green_dim, small=True).pack(side="left", padx=2)

            # Info line
            pid_str = srv.get("place_id") or PLACE_ID
            lc = srv.get("link_code", "")
            owner = srv.get("owner", "")
            info = f"Place: {pid_str}  |  LinkCode: {lc[:20]}..." if len(lc) > 20 else f"Place: {pid_str}  |  LinkCode: {lc or '(none)'}"
            if owner:
                info += f"  |  Owner: {owner}"
            tk.Label(c, text=info, font=("Consolas", 8), bg=Theme.bg_card, fg=Theme.text_dim).pack(anchor="w", pady=(4, 0))

            if manager.accounts:
                tk.Frame(c, bg=Theme.border, height=1).pack(fill="x", pady=(8, 4))
                tk.Label(c, text="RESTART + RELAUNCH", font=("Consolas", 8, "bold"), bg=Theme.bg_card, fg=Theme.text_dim).pack(anchor="w")
                rr = tk.Frame(c, bg=Theme.bg_card)
                rr.pack(anchor="w", pady=(4, 0))
                for an in manager.accounts:
                    self._btn(rr, f"\U0001F504 {an}", lambda a=an, k=key: self._do_restart(a, k), color=Theme.accent_dim, small=True).pack(side="left", padx=(0, 4))

    def _do_add_server(self):
        """Dialog to add a new private server."""
        dlg = tk.Toplevel(self.root)
        dlg.title("Add Private Server")
        dlg.configure(bg=Theme.bg)
        dlg.geometry("520x420")
        dlg.transient(self.root)
        dlg.grab_set()

        pad = {"padx": 12, "pady": (8, 0)}

        tk.Label(dlg, text="Server Name:", font=("Consolas", 10), bg=Theme.bg, fg=Theme.text).pack(anchor="w", **pad)
        name_var = tk.StringVar(value="Farm Server")
        tk.Entry(dlg, textvariable=name_var, font=("Consolas", 10), bg=Theme.bg_card, fg=Theme.text,
                 insertbackground=Theme.text, relief="flat", bd=0).pack(fill="x", padx=12, pady=(2, 0), ipady=4)

        tk.Label(dlg, text="Private Server URL (the redirected URL with privateServerLinkCode):",
                 font=("Consolas", 9), bg=Theme.bg, fg=Theme.text_muted, wraplength=490, justify="left").pack(anchor="w", **pad)
        url_var = tk.StringVar()
        tk.Entry(dlg, textvariable=url_var, font=("Consolas", 9), bg=Theme.bg_card, fg=Theme.text,
                 insertbackground=Theme.text, relief="flat", bd=0).pack(fill="x", padx=12, pady=(2, 0), ipady=4)

        tk.Label(dlg, text="OR paste the linkCode directly (the long number):",
                 font=("Consolas", 9), bg=Theme.bg, fg=Theme.text_dim).pack(anchor="w", padx=12, pady=(2, 0))

        tk.Label(dlg, text="Place ID (leave default unless different game):",
                 font=("Consolas", 10), bg=Theme.bg, fg=Theme.text).pack(anchor="w", **pad)
        pid_var = tk.StringVar(value=str(PLACE_ID))
        tk.Entry(dlg, textvariable=pid_var, font=("Consolas", 10), bg=Theme.bg_card, fg=Theme.text,
                 insertbackground=Theme.text, relief="flat", bd=0).pack(fill="x", padx=12, pady=(2, 0), ipady=4)

        tk.Label(dlg, text="Server ID (optional — only needed if you DON'T own the server):",
                 font=("Consolas", 10), bg=Theme.bg, fg=Theme.text).pack(anchor="w", **pad)
        tk.Label(dlg, text="Get from Roblox API or the privateServerId in a working shutdown request",
                 font=("Consolas", 8), bg=Theme.bg, fg=Theme.text_dim).pack(anchor="w", padx=12, pady=(0, 0))
        sid_var = tk.StringVar(value="")
        tk.Entry(dlg, textvariable=sid_var, font=("Consolas", 10), bg=Theme.bg_card, fg=Theme.text,
                 insertbackground=Theme.text, relief="flat", bd=0).pack(fill="x", padx=12, pady=(2, 0), ipady=4)

        status = tk.Label(dlg, text="", font=("Consolas", 9), bg=Theme.bg, fg=Theme.accent)
        status.pack(anchor="w", padx=12, pady=(8, 0))

        def do_add():
            name = name_var.get().strip()
            url_text = url_var.get().strip()
            pid_text = pid_var.get().strip()
            sid_text = sid_var.get().strip()

            if not name:
                status.config(text="Enter a server name", fg="#ff4444")
                return
            if not url_text:
                status.config(text="Paste the URL or link code", fg="#ff4444")
                return

            link_code = extract_link_code(url_text)
            if not link_code:
                status.config(text="Could not extract linkCode. Paste the full redirected URL\n"
                              "(the one with privateServerLinkCode=XXXXX)", fg="#ff4444")
                return

            try:
                place_id = int(pid_text) if pid_text else PLACE_ID
            except ValueError:
                status.config(text="Invalid Place ID", fg="#ff4444")
                return

            # Parse optional server_id (numeric privateServerId for shutdown)
            server_id = None
            if sid_text:
                try:
                    server_id = int(sid_text)
                except ValueError:
                    status.config(text="Invalid Server ID (must be a number)", fg="#ff4444")
                    return

            key = add_server(name, link_code, place_id, server_id)
            status.config(text=f"Added '{name}'!", fg=Theme.green)
            self.root.after(500, lambda: [dlg.destroy(), self._refresh_servers()])

        btn_frame = tk.Frame(dlg, bg=Theme.bg)
        btn_frame.pack(fill="x", padx=12, pady=(12, 12))
        self._btn(btn_frame, "Add Server", do_add, color=Theme.green_dim).pack(side="right")
        self._btn(btn_frame, "Cancel", dlg.destroy).pack(side="right", padx=(0, 8))

    def _do_remove_server(self, key):
        name = SERVERS.get(key, {}).get("name", key)
        if messagebox.askyesno("Remove Server", f"Remove '{name}'?"):
            remove_server(key)
            self._refresh_servers()
            self.log(f"Removed server: {name}", "warn")

    def _do_edit_server(self, key):
        """Dialog to edit server settings (owner, server_id, etc)."""
        srv = SERVERS.get(key)
        if not srv:
            return

        dlg = tk.Toplevel(self.root)
        dlg.title(f"Edit Server: {srv['name']}")
        dlg.configure(bg=Theme.bg)
        dlg.geometry("400x280")
        dlg.transient(self.root)
        dlg.grab_set()

        pad = {"padx": 12, "pady": (8, 0)}

        tk.Label(dlg, text="Server Name:", font=("Consolas", 10), bg=Theme.bg, fg=Theme.text).pack(anchor="w", **pad)
        name_var = tk.StringVar(value=srv.get("name", ""))
        tk.Entry(dlg, textvariable=name_var, font=("Consolas", 10), bg=Theme.bg_card, fg=Theme.text,
                 insertbackground=Theme.text, relief="flat", bd=0).pack(fill="x", padx=12, pady=(2, 0), ipady=4)

        tk.Label(dlg, text="Owner Account (for shutdown requests):", font=("Consolas", 10), bg=Theme.bg, fg=Theme.text).pack(anchor="w", **pad)
        tk.Label(dlg, text="Leave empty to use any available account", font=("Consolas", 8), bg=Theme.bg, fg=Theme.text_dim).pack(anchor="w", padx=12)

        # Dropdown for owner selection
        owner_var = tk.StringVar(value=srv.get("owner", ""))
        account_names = ["(none)"] + list(manager.accounts.keys())
        owner_menu = ttk.Combobox(dlg, textvariable=owner_var, values=account_names, state="readonly",
                                   font=("Consolas", 10))
        owner_menu.pack(fill="x", padx=12, pady=(2, 0), ipady=2)
        if srv.get("owner") in manager.accounts:
            owner_menu.set(srv.get("owner"))
        else:
            owner_menu.set("(none)")

        tk.Label(dlg, text="Server ID (for shutdown if not owner):", font=("Consolas", 10), bg=Theme.bg, fg=Theme.text).pack(anchor="w", **pad)
        sid_var = tk.StringVar(value=str(srv.get("server_id", "")))
        tk.Entry(dlg, textvariable=sid_var, font=("Consolas", 10), bg=Theme.bg_card, fg=Theme.text,
                 insertbackground=Theme.text, relief="flat", bd=0).pack(fill="x", padx=12, pady=(2, 0), ipady=4)

        status = tk.Label(dlg, text="", font=("Consolas", 9), bg=Theme.bg, fg=Theme.accent)
        status.pack(anchor="w", padx=12, pady=(8, 0))

        def do_save():
            new_name = name_var.get().strip()
            owner_val = owner_var.get().strip()
            sid_text = sid_var.get().strip()

            if not new_name:
                status.config(text="Server name cannot be empty", fg="#ff4444")
                return

            # Update server data
            srv["name"] = new_name

            # Set or clear owner
            if owner_val and owner_val != "(none)":
                srv["owner"] = owner_val
            elif "owner" in srv:
                del srv["owner"]

            # Set or clear server_id
            if sid_text:
                try:
                    srv["server_id"] = int(sid_text)
                except ValueError:
                    status.config(text="Server ID must be a number", fg="#ff4444")
                    return
            elif "server_id" in srv:
                del srv["server_id"]

            save_servers()
            status.config(text="Saved!", fg=Theme.green)
            self.root.after(500, lambda: [dlg.destroy(), self._refresh_servers()])

        btn_frame = tk.Frame(dlg, bg=Theme.bg)
        btn_frame.pack(fill="x", padx=12, pady=(12, 12))
        self._btn(btn_frame, "Save", do_save, color=Theme.green_dim).pack(side="right")
        self._btn(btn_frame, "Cancel", dlg.destroy).pack(side="right", padx=(0, 8))

    def _do_shutdown(self, key):
        self.log(f"Shutting down {key}...", "warn")
        def do():
            try:
                r = manager.shutdown_server(None, key)
                if "error" not in r:
                    msg = f"Shutdown sent! (HTTP {r.get('status', '?')})"
                    lvl = "success"
                else:
                    detail = r.get("body", "") if isinstance(r.get("body"), str) else ""
                    msg = f"Shutdown failed: {r.get('error')}"
                    if detail:
                        msg += f" - {detail[:200]}"
                    lvl = "error"
            except Exception as ex:
                msg = f"Shutdown crashed: {ex}"
                lvl = "error"
            self.root.after(0, lambda: self.log(msg, lvl))
        threading.Thread(target=do, daemon=True).start()

    def _do_srv_launch(self, key):
        names = list(manager.accounts.keys())
        if not names:
            messagebox.showwarning("", "Add an account first")
            return
        acc = simpledialog.askstring("Launch", f"Account for {key}?", initialvalue=names[0])
        if not acc:
            return
        self.log(f"Launching {acc} \u2192 {key}...")
        def do():
            r = manager.launch_instance(acc, key)
            msg = f"Launched! PID: {r['pid']}" if r.get("success") else f"Failed: {r.get('error')}"
            self.root.after(0, lambda: self.log(msg, "success" if r.get("success") else "error"))
        threading.Thread(target=do, daemon=True).start()

    def _do_restart(self, acc, srv):
        self.log(f"Restart+relaunch: {acc} \u2192 {srv}")
        def do():
            r = manager.restart_and_rejoin(acc, srv, delay=5)
            ok = r.get("shutdown") and "error" not in r["shutdown"]
            self.root.after(0, lambda: self.log(
                "Shutdown \u2192 relaunching in 5s" if ok else f"Failed: {r}", "success" if ok else "error"))
        threading.Thread(target=do, daemon=True).start()

    def _do_kill_mutex(self):
        self.log("Cleaning singleton handles from running Roblox processes...")
        def do():
            c = 0
            for p in psutil.process_iter(["pid", "name"]):
                try:
                    if p.info["name"] and "RobloxPlayerBeta" in p.info["name"]:
                        c += close_singleton_from_process(p.info["pid"])
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
            self.root.after(0, lambda: self.log(f"Closed {c} handle(s)", "success" if c else "warn"))
        threading.Thread(target=do, daemon=True).start()

    def _do_kill_all_reset(self):
        """Kill ALL Roblox processes and re-acquire mutex."""
        self.log("Killing ALL Roblox processes and resetting mutex...")
        def do():
            global _held_handles
            killed = 0
            # Kill all Roblox processes
            for p in psutil.process_iter(["pid", "name"]):
                try:
                    if p.info["name"] and "RobloxPlayerBeta" in p.info["name"]:
                        p.kill()
                        killed += 1
                        self.root.after(0, lambda pid=p.info["pid"]: self.log(f"Killed PID {pid}"))
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass

            # Wait a moment for processes to die
            time.sleep(1)

            # Release our held handles
            if IS_WINDOWS:
                kernel32 = ctypes.windll.kernel32
                for h in _held_handles:
                    try:
                        kernel32.CloseHandle(h)
                    except:
                        pass
                _held_handles.clear()

                # Re-acquire mutex
                hold_mutex()

            # Clear tracked instances
            manager.instances.clear()

            self.root.after(0, lambda: self.log(f"Killed {killed} process(es), mutex reset!", "success"))
            self.root.after(0, self._refresh_accounts)
        threading.Thread(target=do, daemon=True).start()

    # ----------------------------------------------------------------
    # SETTINGS TAB
    # ----------------------------------------------------------------
    def _build_settings_tab(self):
        # Create a scrollable container for settings
        outer_frame = tk.Frame(self.content, bg=Theme.bg)
        self.tab_frames["settings"] = outer_frame

        # Canvas for scrolling
        canvas = tk.Canvas(outer_frame, bg=Theme.bg, highlightthickness=0)
        scrollbar = tk.Scrollbar(outer_frame, orient="vertical", command=canvas.yview)
        scrollbar.pack(side="right", fill="y")
        canvas.pack(side="left", fill="both", expand=True)
        canvas.configure(yscrollcommand=scrollbar.set)

        # Inner frame that holds all content
        f = tk.Frame(canvas, bg=Theme.bg)
        canvas_window = canvas.create_window((0, 0), window=f, anchor="nw")

        # Configure canvas scrolling
        def configure_scroll(event):
            canvas.configure(scrollregion=canvas.bbox("all"))
            # Make the inner frame match the canvas width
            canvas.itemconfig(canvas_window, width=event.width)

        canvas.bind("<Configure>", configure_scroll)

        # Enable mousewheel scrolling only when hovering over this canvas
        def on_mousewheel(event):
            canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")

        def bind_mousewheel(event):
            canvas.bind_all("<MouseWheel>", on_mousewheel)

        def unbind_mousewheel(event):
            canvas.unbind_all("<MouseWheel>")

        outer_frame.bind("<Enter>", bind_mousewheel)
        outer_frame.bind("<Leave>", unbind_mousewheel)

        # Private Server Only
        self._lbl(f, "SERVER ENFORCEMENT").pack(anchor="w", pady=(0, 6))
        pc = self._card(f)
        pc.pack(fill="x")

        self.ps_var = tk.BooleanVar(value=False)
        FlatToggle(pc, variable=self.ps_var, text="Private Server Only",
                   command=self._save_settings, bg=Theme.bg_card).pack(anchor="w", pady=(4, 0))

        fr = tk.Frame(pc, bg=Theme.bg_card)
        fr.pack(fill="x", pady=(6, 0))
        tk.Label(fr, text="Forced Server:", font=("Consolas", 9), bg=Theme.bg_card, fg=Theme.text_muted).pack(side="left")
        self.forced_var = tk.StringVar(value="farm")
        om = tk.OptionMenu(fr, self.forced_var, *SERVERS.keys(), command=lambda _: self._save_settings())
        om.configure(font=("Consolas", 9), bg=Theme.bg_input, fg=Theme.text, highlightthickness=0, relief="flat")
        om.pack(side="left", padx=(8, 0))

        tk.Label(pc, text="\U0001F4A1 Executor relaunches to this server\n   if player joins wrong one.",
                 font=("Consolas", 8), bg=Theme.bg_card, fg=Theme.text_dim, justify="left").pack(anchor="w", pady=(6, 0))

        # Auto Rejoin Watchdog
        self._lbl(f, "AUTO REJOIN").pack(anchor="w", pady=(14, 6))
        arc = self._card(f)
        arc.pack(fill="x")

        self.ar_var = tk.BooleanVar(value=self.settings.get("autoRejoin", False))
        FlatToggle(arc, variable=self.ar_var, text="Auto Rejoin (Watchdog)",
                   command=self._save_settings, bg=Theme.bg_card).pack(anchor="w", pady=(4, 0))

        tk.Label(arc, text="\U0001F4A1 Monitors selected accounts and auto-rejoins\n   if their Roblox process goes offline.",
                 font=("Consolas", 8), bg=Theme.bg_card, fg=Theme.text_dim, justify="left").pack(anchor="w", pady=(2, 6))

        # Server selection
        sf = tk.Frame(arc, bg=Theme.bg_card)
        sf.pack(fill="x", pady=(0, 6))
        tk.Label(sf, text="Server:", font=("Consolas", 9), bg=Theme.bg_card, fg=Theme.text_muted).pack(side="left")
        self.ar_srv_var = tk.StringVar(value=self.settings.get("autoRejoinServer", "farm"))
        om2 = tk.OptionMenu(sf, self.ar_srv_var, *SERVERS.keys(), command=lambda _: self._save_settings())
        om2.configure(font=("Consolas", 9), bg=Theme.bg_input, fg=Theme.text, highlightthickness=0, relief="flat")
        om2.pack(side="left", padx=(8, 0))

        # Check interval
        df = tk.Frame(arc, bg=Theme.bg_card)
        df.pack(fill="x", pady=(0, 6))
        tk.Label(df, text="Check every:", font=("Consolas", 9), bg=Theme.bg_card, fg=Theme.text_muted).pack(side="left")
        self.ar_delay_var = tk.IntVar(value=self.settings.get("autoRejoinInterval", 30))
        self.ar_delay_lbl = tk.Label(df, text=f"{self.settings.get('autoRejoinInterval', 30)}s", font=("Consolas", 9, "bold"), bg=Theme.bg_card, fg=Theme.accent, width=5)
        self.ar_delay_lbl.pack(side="left", padx=(8, 0))
        tk.Scale(df, from_=10, to=120, orient="horizontal", variable=self.ar_delay_var,
                 bg=Theme.bg_card, fg=Theme.text, troughcolor=Theme.bg_input,
                 highlightthickness=0, showvalue=False, sliderrelief="flat",
                 command=lambda v: (self.ar_delay_lbl.configure(text=f"{int(float(v))}s"), self._save_settings())).pack(side="left", fill="x", expand=True)

        # Account checkboxes (multi-select)
        tk.Label(arc, text="Watch accounts:", font=("Consolas", 9, "bold"), bg=Theme.bg_card, fg=Theme.text_muted).pack(anchor="w", pady=(0, 4))
        self.ar_acc_frame = tk.Frame(arc, bg=Theme.bg_card)
        self.ar_acc_frame.pack(fill="x")
        self.ar_acc_vars = {}  # {account_name: BooleanVar}
        self._refresh_watchdog_accounts()

        # Heartbeat requirement toggle
        self.ar_heartbeat_var = tk.BooleanVar(value=self.settings.get("requireHeartbeat", True))
        FlatToggle(arc, variable=self.ar_heartbeat_var, text="Require Lua heartbeat",
                   command=self._save_settings, bg=Theme.bg_card).pack(anchor="w", pady=(8, 0))

        self.ar_status = tk.Label(arc, text="", font=("Consolas", 9, "bold"), bg=Theme.bg_card, fg=Theme.accent)
        self.ar_status.pack(anchor="w", pady=(8, 0))

        # Window Layout
        self._lbl(f, "WINDOW LAYOUT").pack(anchor="w", pady=(14, 6))
        wlc = self._card(f)
        wlc.pack(fill="x")

        tk.Label(wlc, text="Save window positions & sizes for all running Roblox instances.\nLayouts are restored automatically when accounts relaunch.",
                 font=("Consolas", 8), bg=Theme.bg_card, fg=Theme.text_dim, justify="left").pack(anchor="w", pady=(0, 8))

        wl_btn_frame = tk.Frame(wlc, bg=Theme.bg_card)
        wl_btn_frame.pack(fill="x")
        self._btn(wl_btn_frame, "\U0001F4BE Save All Window Layouts", self._save_all_layouts, color=Theme.blue_dim).pack(side="left")
        self.wl_status = tk.Label(wl_btn_frame, text="", font=("Consolas", 9), bg=Theme.bg_card, fg=Theme.green)
        self.wl_status.pack(side="left", padx=(12, 0))

        # Bottom spacer to ensure scrolling shows all content
        tk.Frame(f, bg=Theme.bg, height=20).pack(fill="x")

    def _save_all_layouts(self):
        """Save window layouts for all running instances."""
        saved = 0
        for acc_name in manager.accounts:
            if manager.save_window_layout(acc_name):
                saved += 1
        if saved > 0:
            self.wl_status.configure(text=f"Saved {saved} layout(s)", fg=Theme.green)
        else:
            self.wl_status.configure(text="No running instances found", fg=Theme.yellow)
        # Clear status after 3 seconds
        self.root.after(3000, lambda: self.wl_status.configure(text=""))

    def _refresh_watchdog_accounts(self):
        """Rebuild the account checkboxes for the watchdog."""
        for w in self.ar_acc_frame.winfo_children():
            w.destroy()
        self.ar_acc_vars = {}
        saved_watched = self.settings.get("watchdogAccounts", [])
        for name in manager.accounts:
            var = tk.BooleanVar(value=(name in self.watchdog_accounts or name in saved_watched))
            self.ar_acc_vars[name] = var
            FlatCheckbox(self.ar_acc_frame, variable=var, text=name,
                         command=self._save_settings, bg=Theme.bg_card).pack(anchor="w", pady=2)
        if not manager.accounts:
            tk.Label(self.ar_acc_frame, text="  No accounts added yet",
                     font=("Consolas", 8), bg=Theme.bg_card, fg=Theme.text_dim).pack(anchor="w")

    def _save_settings(self):
        self.settings["privateServerOnly"] = self.ps_var.get()
        self.settings["forcedServer"] = self.forced_var.get()
        self.settings["autoRejoin"] = self.ar_var.get()
        self.settings["autoRejoinInterval"] = self.ar_delay_var.get()
        self.settings["autoRejoinServer"] = self.ar_srv_var.get()
        self.settings["requireHeartbeat"] = self.ar_heartbeat_var.get()
        # Update watched accounts from checkboxes
        self.watchdog_accounts = {}
        srv = self.ar_srv_var.get()
        for name, var in self.ar_acc_vars.items():
            if var.get():
                self.watchdog_accounts[name] = srv
        self.settings["watchdogAccounts"] = list(self.watchdog_accounts.keys())
        self._setup_watchdog()
        self._update_bottom()
        # Persist to disk so settings survive restarts
        save_ui_settings(self.settings)
        # Persist to disk so settings survive restarts
        self._persist_settings()

    def _persist_settings(self):
        """Save watchdog/UI settings to the data file so they survive restarts."""
        try:
            data = {}
            if os.path.exists(DATA_FILE):
                with open(DATA_FILE, "r") as f:
                    data = json.load(f)
            data["ui_settings"] = {
                "privateServerOnly": self.settings["privateServerOnly"],
                "forcedServer": self.settings["forcedServer"],
                "autoRejoin": self.settings["autoRejoin"],
                "autoRejoinInterval": self.settings["autoRejoinInterval"],
                "autoRejoinServer": self.settings["autoRejoinServer"],
                "watchdogAccounts": self.settings.get("watchdogAccounts", []),
            }
            with open(DATA_FILE, "w") as f:
                json.dump(data, f, indent=2)
        except Exception:
            pass

    def _apply_persisted_settings_to_ui(self):
        """After UI is built, apply persisted settings to the UI widgets."""
        self.ps_var.set(self.settings["privateServerOnly"])
        self.forced_var.set(self.settings["forcedServer"])
        self.ar_var.set(self.settings["autoRejoin"])
        self.ar_delay_var.set(self.settings["autoRejoinInterval"])
        self.ar_delay_lbl.configure(text=f"{self.settings['autoRejoinInterval']}s")
        self.ar_srv_var.set(self.settings["autoRejoinServer"])
        self._refresh_watchdog_accounts()
        self._setup_watchdog()

    def _setup_watchdog(self):
        """Start or stop the watchdog polling loop."""
        if self.auto_restart_job:
            self.root.after_cancel(self.auto_restart_job)
            self.auto_restart_job = None

        if self.settings["autoRejoin"] and self.watchdog_accounts:
            interval_s = self.settings["autoRejoinInterval"]
            names = list(self.watchdog_accounts.keys())
            srv = self.settings["autoRejoinServer"]
            self.ar_status.configure(
                text=f"\U0001F6E1 Watching {len(names)} account(s) → {srv} (every {interval_s}s)")
            self.log(f"Watchdog ON: {', '.join(names)} → {srv} (check every {interval_s}s)")

            # Cooldown: don't relaunch same account within 120s of last relaunch
            relaunch_cooldowns = {}  # {acc_name: timestamp of last relaunch}
            currently_launching = set()  # Accounts currently being launched (prevents double-launch)
            check_count = [0]

            def check():
                check_count[0] += 1
                now = time.time()
                require_heartbeat = self.settings.get("requireHeartbeat", True)

                # Periodic orphan cleanup: kill zombie Roblox processes not tracked by healthy instances
                if check_count[0] % 3 == 0:
                    try:
                        orphans_killed = manager.cleanup_orphan_processes(require_heartbeat=require_heartbeat)
                        if orphans_killed:
                            self.root.after(0, lambda k=orphans_killed: self.log(
                                f"\U0001F9F9 Orphan cleanup: killed {k} zombie process(es)", "warn"))
                    except Exception as ex:
                        self.root.after(0, lambda e=str(ex): self.log(f"Orphan cleanup error: {e}", "error"))

                # Collect accounts that need relaunching
                accounts_to_relaunch = []

                for acc_name in list(self.watchdog_accounts.keys()):
                    try:
                        # OPTIMIZATION: Skip full status check if heartbeat is very fresh (< 10s old)
                        acc_data = manager.accounts.get(acc_name, {})
                        roblox_username = acc_data.get("username", "")
                        report = manager.player_reports.get(roblox_username)
                        if report and (time.time() - report["timestamp"]) < 10:
                            # Very fresh heartbeat - definitely alive, skip expensive checks
                            continue

                        running, pid, _ = manager.get_instance_status(acc_name, require_heartbeat=require_heartbeat)

                        if running:
                            # Periodically save window layouts for running instances
                            # This captures user resize/move changes
                            if check_count[0] % 10 == 0:
                                manager.save_window_layout(acc_name)
                            # Only log every 5th check to reduce spam
                            if check_count[0] % 5 == 0:
                                self.root.after(0, lambda a=acc_name, p=pid: self.log(
                                    f"\U0001F6E1 {a}: alive (pid={p})", "dim"))
                            continue

                        # ── Account is NOT running ──

                        # Skip if already being launched (prevents double-launch)
                        if acc_name in currently_launching:
                            continue

                        # Check cooldown — don't spam relaunches
                        last_relaunch = relaunch_cooldowns.get(acc_name, 0)
                        cooldown_remaining = 120 - (now - last_relaunch)
                        if cooldown_remaining > 0:
                            if check_count[0] % 3 == 0:
                                self.root.after(0, lambda a=acc_name, cd=int(cooldown_remaining): self.log(
                                    f"\u23F3 {a}: offline, cooldown {cd}s remaining", "dim"))
                            continue

                        # Determine why it's offline
                        inst = manager.instances.get(acc_name)
                        if inst and inst.get("pid"):
                            process_alive = False
                            try:
                                process_alive = psutil.Process(inst["pid"]).is_running()
                            except (psutil.NoSuchProcess, psutil.AccessDenied):
                                pass
                            if process_alive:
                                reason = "process alive but no heartbeat (disconnected/stuck)"
                            else:
                                reason = "process dead (crashed/closed)"
                        else:
                            reason = "no tracked instance (not launched or cleared)"

                        self.root.after(0, lambda a=acc_name, r=reason: self.log(
                            f"\U0001F6A8 {a} is offline ({r}) — queued for relaunch", "warn"))
                        relaunch_cooldowns[acc_name] = now
                        accounts_to_relaunch.append(acc_name)
                    except Exception as ex:
                        self.root.after(0, lambda e=str(ex): self.log(f"Watchdog error: {e}", "error"))

                # Relaunch offline accounts sequentially
                for acc_name in accounts_to_relaunch:
                    # Double-check account isn't already running before launching
                    running, pid, _ = manager.get_instance_status(acc_name, require_heartbeat=False)
                    if running and pid:
                        self.log(f"⚠️ {acc_name} already running (PID {pid}), skipping relaunch")
                        continue
                    currently_launching.add(acc_name)
                    self._watchdog_rejoin(acc_name, srv)
                    currently_launching.discard(acc_name)

                self.auto_restart_job = self.root.after(interval_s * 1000, check)
            self.auto_restart_job = self.root.after(interval_s * 1000, check)
        elif self.settings["autoRejoin"]:
            self.ar_status.configure(text="\u26A0 No accounts selected")
        else:
            self.ar_status.configure(text="")

    def _watchdog_rejoin(self, acc_name, srv_key):
        """Rejoin an account that went offline. Runs in background thread.
        Kills the stale Roblox process first (disconnect screen), then relaunches."""
        try:
            # Kill the stale process if it's still running (e.g. sitting on disconnect screen)
            inst = manager.instances.get(acc_name)
            if inst and inst.get("pid"):
                try:
                    p = psutil.Process(inst["pid"])
                    if p.is_running():
                        # Save window layout before killing (so we can restore on relaunch)
                        manager.save_window_layout(acc_name)
                        p.kill()
                        self.root.after(0, lambda: self.log(
                            f"\U0001F4A5 Killed stale process for {acc_name} (PID {inst['pid']})"))
                        time.sleep(1)
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
            manager.instances.pop(acc_name, None)

            # Kill any orphan Roblox processes before launching a new one
            # This prevents zombie windows from piling up when PID tracking failed
            orphans = manager.cleanup_orphan_processes()
            if orphans:
                self.root.after(0, lambda k=orphans: self.log(
                    f"\U0001F9F9 Pre-launch cleanup: killed {k} orphan(s)", "warn"))
                time.sleep(1)

            # Clear old heartbeat so get_instance_status hits the grace period
            # instead of seeing a stale timestamp from the previous process
            acc_data = manager.accounts.get(acc_name, {})
            roblox_username = acc_data.get("username", "")
            if roblox_username and roblox_username in manager.player_reports:
                del manager.player_reports[roblox_username]

            actual_srv = manager.get_default_server(acc_name) or srv_key
            result = manager.launch_instance(acc_name, actual_srv)
            if result.get("success"):
                self.root.after(0, lambda a=acc_name, s=actual_srv: self.log(
                    f"\u2705 {a} relaunched to {s}", "success"))
            else:
                err = result.get("error", "unknown")
                self.root.after(0, lambda: self.log(
                    f"\u274C {acc_name} relaunch failed: {err}", "error"))

            # Wait 5s after launch to let autoexec complete before launching next account
            time.sleep(5)
        except Exception as ex:
            self.root.after(0, lambda: self.log(
                f"\u274C {acc_name} relaunch crashed: {ex}", "error"))

    # ----------------------------------------------------------------
    # LOGS TAB
    # ----------------------------------------------------------------
    def _build_logs_tab(self):
        f = tk.Frame(self.content, bg=Theme.bg)
        self.tab_frames["logs"] = f

        top = tk.Frame(f, bg=Theme.bg)
        top.pack(fill="x", pady=(0, 6))
        self._lbl(top, "ACTIVITY LOG").pack(side="left")
        self._btn(top, "Clear", lambda: (self.logs.clear(), self._update_log_display()), color=Theme.text_dim, small=True).pack(side="right")

        self.log_text = tk.Text(f, font=("Consolas", 9), bg=Theme.bg_card, fg=Theme.text_muted,
                                relief="flat", highlightbackground=Theme.border, highlightthickness=1,
                                wrap="word", state="disabled", padx=8, pady=8)
        self.log_text.pack(fill="both", expand=True)
        self.log_text.tag_configure("dim", foreground=Theme.text_dim)
        self.log_text.tag_configure("info", foreground=Theme.text_muted)
        self.log_text.tag_configure("success", foreground=Theme.green)
        self.log_text.tag_configure("error", foreground=Theme.red)
        self.log_text.tag_configure("warn", foreground=Theme.yellow)

    # ----------------------------------------------------------------
    # BOTTOM BAR
    # ----------------------------------------------------------------
    def _update_bottom(self):
        n = len(manager.accounts)
        r = sum(1 for nm in manager.accounts if manager.get_instance_status(nm)[0])
        self.bot_left.configure(text=f"{n} account{'s' if n != 1 else ''} \u00b7 {r} running")

        flags = []
        if self.settings.get("autoRejoin") and self.watchdog_accounts:
            flags.append(f"\U0001F6E1 Watchdog ({len(self.watchdog_accounts)})")
        if self.settings.get("privateServerOnly"):
            flags.append("\U0001F512 PS-Only")
        self.bot_right.configure(text="  ".join(flags))


# ============================================================================
# MAIN
# ============================================================================

def main():
    # Show profile selection dialog first
    select_profile()

    # Now load data with the selected profile
    load_servers()
    manager.load_data()

    api_thread = threading.Thread(target=start_api_server, daemon=True)
    api_thread.start()
    print(f"[+] API on http://localhost:{PORT}")

    root = tk.Tk()
    app = RobloxManagerApp(root)

    def poll():
        if app.current_tab.get() == "accounts":
            app._refresh_accounts()
        elif app.current_tab.get() == "settings":
            # Refresh watchdog account list if accounts changed
            current_names = set(app.ar_acc_vars.keys())
            actual_names = set(manager.accounts.keys())
            if current_names != actual_names:
                app._refresh_watchdog_accounts()
        app._update_bottom()
        root.after(5000, poll)
    root.after(5000, poll)

    root.mainloop()


if __name__ == "__main__":
    main()
