using System.Net;
using System.Text;
using Newtonsoft.Json;

namespace RobloxManager.Classes
{
    public class HttpApiServer
    {
        private readonly HttpListener _listener;
        private readonly DataManager _dataManager;
        private readonly InstanceLauncher _launcher;
        private readonly int _port;
        private bool _running;

        // Player reports from Lua heartbeats: username -> HeartbeatData
        public Dictionary<string, HeartbeatData> PlayerReports { get; } = new();

        public event Action<string>? OnLog;
        public event Action? OnHeartbeat;

        public HttpApiServer(DataManager dataManager, InstanceLauncher launcher, int port = 8080)
        {
            _dataManager = dataManager;
            _launcher = launcher;
            _port = port;
            _listener = new HttpListener();
            _listener.Prefixes.Add($"http://localhost:{port}/");
            _listener.Prefixes.Add($"http://127.0.0.1:{port}/");
        }

        public void Start()
        {
            try
            {
                _listener.Start();
                _running = true;
                _ = Task.Run(ListenLoop);
                OnLog?.Invoke($"[API] Server started on port {_port}");
            }
            catch (Exception ex)
            {
                OnLog?.Invoke($"[API] Failed to start: {ex.Message}");
            }
        }

        public void Stop()
        {
            _running = false;
            _listener.Stop();
        }

        private async Task ListenLoop()
        {
            while (_running)
            {
                try
                {
                    var context = await _listener.GetContextAsync();
                    _ = Task.Run(() => HandleRequest(context));
                }
                catch (Exception ex)
                {
                    if (_running)
                        OnLog?.Invoke($"[API] Error: {ex.Message}");
                }
            }
        }

        private async Task HandleRequest(HttpListenerContext context)
        {
            var request = context.Request;
            var response = context.Response;
            var path = request.Url?.AbsolutePath.Trim('/') ?? "";
            var parts = path.Split('/');

            // CORS headers
            response.Headers.Add("Access-Control-Allow-Origin", "*");
            response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
            response.Headers.Add("Access-Control-Allow-Headers", "Content-Type");
            response.ContentType = "application/json";

            if (request.HttpMethod == "OPTIONS")
            {
                response.StatusCode = 200;
                response.Close();
                return;
            }

            object result;

            try
            {
                result = await RouteRequest(request.HttpMethod, parts, request);
                response.StatusCode = 200;
            }
            catch (Exception ex)
            {
                result = new { error = ex.Message };
                response.StatusCode = 500;
            }

            var json = JsonConvert.SerializeObject(result);
            var buffer = Encoding.UTF8.GetBytes(json);
            response.ContentLength64 = buffer.Length;
            await response.OutputStream.WriteAsync(buffer);
            response.Close();
        }

        private async Task<object> RouteRequest(string method, string[] parts, HttpListenerRequest request)
        {
            var path = string.Join("/", parts);

            // GET /status
            if (path == "status")
            {
                return new
                {
                    status = "running",
                    accounts = _dataManager.Accounts.Count,
                    servers = _dataManager.Servers.Count,
                    heartbeats = PlayerReports.Count
                };
            }

            // GET /accounts
            if (path == "accounts")
            {
                return _dataManager.Accounts.Select(kv => new
                {
                    name = kv.Key,
                    username = kv.Value.Username,
                    status = kv.Value.Status.ToString().ToLower(),
                    pid = kv.Value.ProcessId,
                    server = kv.Value.CurrentServer
                }).ToList();
            }

            // GET /servers
            if (path == "servers")
            {
                return _dataManager.Servers;
            }

            // GET /players
            if (path == "players")
            {
                return PlayerReports.Values.ToList();
            }

            // POST /heartbeat
            if (path == "heartbeat" && method == "POST")
            {
                using var reader = new StreamReader(request.InputStream);
                var body = await reader.ReadToEndAsync();
                var data = JsonConvert.DeserializeObject<HeartbeatRequest>(body);

                if (data != null)
                {
                    ProcessHeartbeat(data);
                    OnHeartbeat?.Invoke();
                    return new { status = "ok" };
                }
                return new { error = "Invalid heartbeat data" };
            }

            // GET /launch/<account>/<server>
            if (parts.Length >= 2 && parts[0] == "launch")
            {
                var accountName = parts[1];
                var serverKey = parts.Length > 2 ? parts[2] : null;
                var result = await _launcher.LaunchAccount(accountName, serverKey);
                return result;
            }

            // GET /restart/<server>
            if (parts.Length >= 2 && parts[0] == "restart")
            {
                var serverKey = parts[1];
                // Kill all accounts assigned to this server and relaunch
                var accountsToRestart = _dataManager.Accounts
                    .Where(a => a.Value.DefaultServer == serverKey)
                    .Select(a => a.Key)
                    .ToList();

                foreach (var name in accountsToRestart)
                {
                    _launcher.KillInstance(name);
                }

                await Task.Delay(2000);

                foreach (var name in accountsToRestart)
                {
                    await _launcher.LaunchAccount(name, serverKey);
                    await Task.Delay(3000); // Stagger launches
                }

                return new { status = "ok", restarted = accountsToRestart };
            }

            // GET /my-server/<username>
            if (parts.Length >= 2 && parts[0] == "my-server")
            {
                var username = parts[1].ToLower();
                var account = _dataManager.Accounts
                    .FirstOrDefault(a => a.Key.ToLower() == username || a.Value.Username.ToLower() == username);

                if (account.Value != null)
                {
                    return new { server = account.Value.DefaultServer };
                }
                return new { server = "farm" };
            }

            return new { error = "Unknown endpoint" };
        }

        private void ProcessHeartbeat(HeartbeatRequest data)
        {
            var heartbeat = new HeartbeatData
            {
                Username = data.Username,
                Server = data.Server,
                Players = data.Players ?? new List<string>(),
                JobId = data.JobId ?? "",
                Timestamp = DateTime.Now
            };

            PlayerReports[data.Username] = heartbeat;
            OnLog?.Invoke($"[HEARTBEAT] {data.Username} in '{data.Server}' with {heartbeat.Players.Count} players");

            // Update account's last heartbeat
            var account = _dataManager.Accounts
                .FirstOrDefault(a => a.Value.Username.Equals(data.Username, StringComparison.OrdinalIgnoreCase));
            if (account.Value != null)
            {
                account.Value.LastHeartbeat = DateTime.Now;
                account.Value.Status = AccountStatus.Running;
            }
        }
    }

    public class HeartbeatRequest
    {
        [JsonProperty("username")]
        public string Username { get; set; } = "";

        [JsonProperty("server")]
        public string Server { get; set; } = "";

        [JsonProperty("players")]
        public List<string>? Players { get; set; }

        [JsonProperty("jobId")]
        public string? JobId { get; set; }
    }

    public class HeartbeatData
    {
        public string Username { get; set; } = "";
        public string Server { get; set; } = "";
        public List<string> Players { get; set; } = new();
        public string JobId { get; set; } = "";
        public DateTime Timestamp { get; set; }
    }
}
