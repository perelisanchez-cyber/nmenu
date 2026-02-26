using Newtonsoft.Json;

namespace RobloxManager.Classes
{
    public class Server
    {
        [JsonProperty("name")]
        public string Name { get; set; } = "";

        [JsonProperty("placeId")]
        public long PlaceId { get; set; }

        [JsonProperty("linkCode")]
        public string LinkCode { get; set; } = "";

        [JsonProperty("serverId")]
        public long ServerId { get; set; }

        [JsonProperty("owner")]
        public string Owner { get; set; } = "";

        // Runtime state
        [JsonIgnore]
        public int PlayerCount { get; set; }

        [JsonIgnore]
        public List<string> Players { get; set; } = new();

        [JsonIgnore]
        public DateTime LastUpdate { get; set; }

        public bool IsPrivate => !string.IsNullOrEmpty(LinkCode);
    }
}
