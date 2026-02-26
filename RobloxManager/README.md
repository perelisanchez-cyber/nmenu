# Roblox Manager (C# Version)

A native Windows application for managing multiple Roblox accounts. Built with .NET 6 and WinForms.

## Features

- **Multi-Account Management**: Add, edit, and manage multiple Roblox accounts
- **Server Management**: Configure private and public servers
- **Multi-Instance Support**: Launch multiple Roblox instances (mutex bypass like RAM)
- **HTTP API**: Built-in API server for Lua heartbeats (port 8080)
- **Watchdog**: Auto-rejoin disconnected accounts
- **Modern Dark UI**: Clean, dark-themed interface
- **Window Layout**: Save and restore window positions

## Requirements

- Windows 10/11
- .NET 6.0 SDK (for building)
- .NET 6.0 Runtime (for running)

## Building

### Option 1: Using Visual Studio
1. Open `RobloxManager.sln` in Visual Studio 2022
2. Build → Build Solution (Ctrl+Shift+B)
3. Output: `bin/Release/net6.0-windows/RobloxManager.exe`

### Option 2: Using Command Line
```cmd
cd RobloxManager
dotnet build -c Release
```

### Option 3: Publish as Single Exe
```cmd
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```
Output: `bin/Release/net6.0-windows/win-x64/publish/RobloxManager.exe`

## Usage

1. Place `RobloxManager.exe` in a folder
2. Run the exe - select your profile (Unlock/Shake)
3. Add accounts with their .ROBLOSECURITY cookies
4. Configure servers with private server link codes
5. Launch accounts!

## API Endpoints

The manager runs an HTTP server on `localhost:8080`:

- `GET /status` - Server status
- `GET /accounts` - List all accounts
- `GET /servers` - List all servers
- `POST /heartbeat` - Lua heartbeat (players, server info)
- `GET /launch/<account>/<server>` - Launch an account
- `GET /my-server/<username>` - Get account's default server

## Data Files

- `roblox_manager_data_unlock.json` - Unlock profile data
- `roblox_manager_data_shake.json` - Shake profile data

## License

Private use only.
