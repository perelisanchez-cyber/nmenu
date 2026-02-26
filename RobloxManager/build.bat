@echo off
echo ========================================
echo Building Roblox Manager (C#)
echo ========================================
echo.

REM Check for .NET SDK
dotnet --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] .NET SDK not found!
    echo Please install .NET 6.0 SDK from: https://dotnet.microsoft.com/download
    pause
    exit /b 1
)

echo [*] Restoring packages...
dotnet restore

echo [*] Building Release version...
dotnet build -c Release

if exist "bin\Release\net6.0-windows\RobloxManager.exe" (
    echo.
    echo ========================================
    echo [SUCCESS] Built: bin\Release\net6.0-windows\RobloxManager.exe
    echo ========================================
) else (
    echo.
    echo [ERROR] Build failed!
)

echo.
echo [*] Publishing single-file exe...
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true

if exist "bin\Release\net6.0-windows\win-x64\publish\RobloxManager.exe" (
    echo.
    echo ========================================
    echo [SUCCESS] Single exe: bin\Release\net6.0-windows\win-x64\publish\RobloxManager.exe
    echo ========================================
    echo.
    echo Copy this exe to the folder with your data files!
)

pause
