using Newtonsoft.Json;

namespace RobloxManager.Classes
{
    public class DataManager
    {
        private readonly string _dataFilePath;
        private DataFile _data;

        public Dictionary<string, Account> Accounts => _data.Accounts;
        public Dictionary<string, Server> Servers => _data.Servers;
        public Settings Settings => _data.Settings;

        public DataManager(string profile)
        {
            var baseDir = AppDomain.CurrentDomain.BaseDirectory;
            _dataFilePath = Path.Combine(baseDir, $"roblox_manager_data_{profile.ToLower()}.json");
            _data = new DataFile();
            Load();
        }

        public void Load()
        {
            try
            {
                if (File.Exists(_dataFilePath))
                {
                    var json = File.ReadAllText(_dataFilePath);
                    _data = JsonConvert.DeserializeObject<DataFile>(json) ?? new DataFile();
                    Console.WriteLine($"[+] Loaded data from {_dataFilePath}");
                }
                else
                {
                    Console.WriteLine($"[*] Data file not found, using defaults: {_dataFilePath}");
                    _data = new DataFile();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[!] Error loading data: {ex.Message}");
                _data = new DataFile();
            }
        }

        public void Save()
        {
            try
            {
                var json = JsonConvert.SerializeObject(_data, Formatting.Indented);
                File.WriteAllText(_dataFilePath, json);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[!] Error saving data: {ex.Message}");
            }
        }

        public void AddAccount(string name, Account account)
        {
            _data.Accounts[name] = account;
            Save();
        }

        public void RemoveAccount(string name)
        {
            _data.Accounts.Remove(name);
            Save();
        }

        public void AddServer(string key, Server server)
        {
            _data.Servers[key] = server;
            Save();
        }

        public void RemoveServer(string key)
        {
            _data.Servers.Remove(key);
            Save();
        }

        public void UpdateSettings(Settings settings)
        {
            _data.Settings = settings;
            Save();
        }
    }

    public class DataFile
    {
        [JsonProperty("accounts")]
        public Dictionary<string, Account> Accounts { get; set; } = new();

        [JsonProperty("servers")]
        public Dictionary<string, Server> Servers { get; set; } = new();

        [JsonProperty("settings")]
        public Settings Settings { get; set; } = new();
    }

    public class Settings
    {
        [JsonProperty("privateServerOnly")]
        public bool PrivateServerOnly { get; set; }

        [JsonProperty("forcedServer")]
        public string ForcedServer { get; set; } = "farm";

        [JsonProperty("autoRejoin")]
        public bool AutoRejoin { get; set; }

        [JsonProperty("autoRejoinInterval")]
        public int AutoRejoinInterval { get; set; } = 30;

        [JsonProperty("autoRejoinServer")]
        public string AutoRejoinServer { get; set; } = "farm";

        [JsonProperty("requireHeartbeat")]
        public bool RequireHeartbeat { get; set; } = true;

        [JsonProperty("watchdogAccounts")]
        public List<string> WatchdogAccounts { get; set; } = new();
    }
}
