using Newtonsoft.Json;

namespace RobloxManager.Classes
{
    public class Account
    {
        [JsonProperty("cookie")]
        public string Cookie { get; set; } = "";

        [JsonProperty("username")]
        public string Username { get; set; } = "";

        [JsonProperty("userId")]
        public long UserId { get; set; }

        [JsonProperty("displayName")]
        public string DisplayName { get; set; } = "";

        [JsonProperty("defaultServer")]
        public string DefaultServer { get; set; } = "farm";

        [JsonProperty("priority")]
        public int Priority { get; set; } = 100;

        [JsonProperty("windowLayout")]
        public WindowLayout? WindowLayout { get; set; }

        // Runtime state (not persisted)
        [JsonIgnore]
        public int ProcessId { get; set; }

        [JsonIgnore]
        public string CurrentServer { get; set; } = "";

        [JsonIgnore]
        public DateTime LaunchedAt { get; set; }

        [JsonIgnore]
        public DateTime LastHeartbeat { get; set; }

        [JsonIgnore]
        public AccountStatus Status { get; set; } = AccountStatus.Offline;

        public bool IsRunning => Status == AccountStatus.Running || Status == AccountStatus.Launching;
    }

    public class WindowLayout
    {
        [JsonProperty("x")]
        public int X { get; set; }

        [JsonProperty("y")]
        public int Y { get; set; }

        [JsonProperty("width")]
        public int Width { get; set; }

        [JsonProperty("height")]
        public int Height { get; set; }
    }

    public enum AccountStatus
    {
        Offline,
        Launching,
        Running,
        Stuck,
        Error
    }
}
