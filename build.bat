@echo off
echo ========================================
echo Building Roblox Manager exe...
echo ========================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found! Please install Python 3.8+ and add to PATH.
    pause
    exit /b 1
)

REM Install requirements
echo [*] Installing dependencies...
pip install pyinstaller psutil pycryptodome >nul 2>&1

REM Build exe
echo [*] Building exe (this may take a minute)...
pyinstaller --onefile --name RobloxManager roblox_manager__39_.py

if exist dist\RobloxManager.exe (
    echo.
    echo ========================================
    echo [SUCCESS] Built: dist\RobloxManager.exe
    echo ========================================
    echo.
    echo Copy RobloxManager.exe to the same folder as your
    echo roblox_manager_data_unlock.json or roblox_manager_data_shake.json
    echo.
) else (
    echo.
    echo [ERROR] Build failed!
    echo.
)

pause
