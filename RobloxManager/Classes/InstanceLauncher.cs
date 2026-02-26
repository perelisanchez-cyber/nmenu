using System.Diagnostics;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Web;

namespace RobloxManager.Classes
{
    public class InstanceLauncher
    {
        private static Mutex? _robloxMutex;
        private static EventWaitHandle? _robloxEvent;
        private readonly DataManager _dataManager;

        // P/Invoke for ShellExecute
        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr ShellExecuteW(
            IntPtr hwnd,
            string lpOperation,
            string lpFile,
            string? lpParameters,
            string? lpDirectory,
            int nShowCmd
        );

        private const int SW_SHOWNORMAL = 1;

        public InstanceLauncher(DataManager dataManager)
        {
            _dataManager = dataManager;
        }

        public static void HoldMutex()
        {
            try
            {
                // Create and hold the Roblox singleton mutex
                _robloxMutex = new Mutex(true, "ROBLOX_singletonMutex");
                Console.WriteLine("[+] Holding ROBLOX_singletonMutex");

                // Create and hold the Roblox singleton event
                _robloxEvent = new EventWaitHandle(false, EventResetMode.ManualReset, "ROBLOX_singletonEvent");
                Console.WriteLine("[+] Holding ROBLOX_singletonEvent");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[!] Failed to hold mutex: {ex.Message}");
            }
        }

        public async Task<LaunchResult> LaunchAccount(string accountName, string? serverKey = null)
        {
            if (!_dataManager.Accounts.TryGetValue(accountName, out var account))
            {
                return new LaunchResult { Success = false, Error = "Account not found" };
            }

            // Check if already running
            if (account.IsRunning)
            {
                return new LaunchResult { Success = false, Error = "Account already running" };
            }

            // Get auth ticket
            var ticket = await GetAuthTicket(account.Cookie);
            if (string.IsNullOrEmpty(ticket))
            {
                return new LaunchResult { Success = false, Error = "Failed to get auth ticket" };
            }

            // Build launch URL
            var launchUrl = BuildLaunchUrl(ticket, serverKey);
            if (string.IsNullOrEmpty(launchUrl))
            {
                return new LaunchResult { Success = false, Error = "Failed to build launch URL" };
            }

            // Get PIDs before launch
            var pidsBefore = GetRobloxPids();

            // Launch via ShellExecute (same as RAM)
            var result = ShellExecuteW(IntPtr.Zero, "open", launchUrl, null, null, SW_SHOWNORMAL);
            if ((int)result <= 32)
            {
                return new LaunchResult { Success = false, Error = $"ShellExecute failed with code {(int)result}" };
            }

            // Update account state
            account.Status = AccountStatus.Launching;
            account.LaunchedAt = DateTime.Now;
            account.CurrentServer = serverKey ?? "";

            // Track the new process in background
            _ = Task.Run(async () =>
            {
                await TrackNewProcess(accountName, pidsBefore);
            });

            return new LaunchResult { Success = true, AccountName = accountName };
        }

        private async Task TrackNewProcess(string accountName, HashSet<int> pidsBefore)
        {
            if (!_dataManager.Accounts.TryGetValue(accountName, out var account))
                return;

            for (int i = 0; i < 30; i++) // Try for 30 seconds
            {
                await Task.Delay(1000);

                foreach (var proc in Process.GetProcessesByName("RobloxPlayerBeta"))
                {
                    try
                    {
                        if (!pidsBefore.Contains(proc.Id))
                        {
                            account.ProcessId = proc.Id;
                            account.Status = AccountStatus.Running;
                            Console.WriteLine($"[PID] {accountName}: tracked PID {proc.Id}");

                            // Restore window layout if saved
                            if (account.WindowLayout != null)
                            {
                                await Task.Delay(2000); // Wait for window to appear
                                RestoreWindowLayout(proc.Id, account.WindowLayout);
                            }
                            return;
                        }
                    }
                    catch { }
                }
            }

            Console.WriteLine($"[!] {accountName}: could not find new Roblox process");
            account.Status = AccountStatus.Error;
        }

        private HashSet<int> GetRobloxPids()
        {
            var pids = new HashSet<int>();
            foreach (var proc in Process.GetProcessesByName("RobloxPlayerBeta"))
            {
                try { pids.Add(proc.Id); } catch { }
            }
            return pids;
        }

        private async Task<string?> GetAuthTicket(string cookie)
        {
            try
            {
                using var client = new HttpClient();
                client.DefaultRequestHeaders.Add("Cookie", $".ROBLOSECURITY={cookie}");
                client.DefaultRequestHeaders.Add("Referer", "https://www.roblox.com/");

                var response = await client.PostAsync(
                    "https://auth.roblox.com/v1/authentication-ticket",
                    null
                );

                if (response.Headers.TryGetValues("rbx-authentication-ticket", out var values))
                {
                    return values.FirstOrDefault();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[!] Auth ticket error: {ex.Message}");
            }
            return null;
        }

        private string? BuildLaunchUrl(string ticket, string? serverKey)
        {
            var random = new Random();
            var browserTrackerId = $"{random.Next(100000, 175000)}{random.Next(100000, 900000)}";
            var launchTime = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            long placeId = 133322550157181; // Default place ID

            string placelauncherUrl;

            if (!string.IsNullOrEmpty(serverKey) && _dataManager.Servers.TryGetValue(serverKey, out var server))
            {
                placeId = server.PlaceId > 0 ? server.PlaceId : placeId;
                placelauncherUrl = HttpUtility.UrlEncode(
                    $"https://assetgame.roblox.com/game/PlaceLauncher.ashx" +
                    $"?request=RequestPrivateGame&placeId={placeId}&accessCode=&linkCode={server.LinkCode}"
                );
            }
            else
            {
                placelauncherUrl = HttpUtility.UrlEncode(
                    $"https://assetgame.roblox.com/game/PlaceLauncher.ashx" +
                    $"?request=RequestGame&browserTrackerId={browserTrackerId}&placeId={placeId}"
                );
            }

            return $"roblox-player:1+launchmode:play+gameinfo:{ticket}+launchtime:{launchTime}" +
                   $"+placelauncherurl:{placelauncherUrl}" +
                   $"+browsertrackerid:{browserTrackerId}+robloxLocale:en_us+gameLocale:en_us+channel:+LaunchExp:InApp";
        }

        public void KillInstance(string accountName)
        {
            if (!_dataManager.Accounts.TryGetValue(accountName, out var account))
                return;

            if (account.ProcessId > 0)
            {
                try
                {
                    var proc = Process.GetProcessById(account.ProcessId);
                    proc.Kill();
                    Console.WriteLine($"[*] Killed {accountName} (PID {account.ProcessId})");
                }
                catch { }
            }

            account.ProcessId = 0;
            account.Status = AccountStatus.Offline;
        }

        public void KillAllInstances()
        {
            foreach (var proc in Process.GetProcessesByName("RobloxPlayerBeta"))
            {
                try
                {
                    proc.Kill();
                    Console.WriteLine($"[*] Killed Roblox PID {proc.Id}");
                }
                catch { }
            }

            foreach (var account in _dataManager.Accounts.Values)
            {
                account.ProcessId = 0;
                account.Status = AccountStatus.Offline;
            }
        }

        // Window layout helpers
        [DllImport("user32.dll")]
        private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        private void RestoreWindowLayout(int processId, WindowLayout layout)
        {
            IntPtr hwnd = IntPtr.Zero;

            EnumWindows((hWnd, lParam) =>
            {
                GetWindowThreadProcessId(hWnd, out uint pid);
                if (pid == processId)
                {
                    hwnd = hWnd;
                    return false;
                }
                return true;
            }, IntPtr.Zero);

            if (hwnd != IntPtr.Zero)
            {
                SetWindowPos(hwnd, IntPtr.Zero, layout.X, layout.Y, layout.Width, layout.Height, 0);
                Console.WriteLine($"[LAYOUT] Restored window to {layout.Width}x{layout.Height} at ({layout.X}, {layout.Y})");
            }
        }
    }

    public class LaunchResult
    {
        public bool Success { get; set; }
        public string? Error { get; set; }
        public string? AccountName { get; set; }
    }
}
