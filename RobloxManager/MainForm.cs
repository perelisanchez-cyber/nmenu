using System.ComponentModel;
using RobloxManager.Classes;

namespace RobloxManager
{
    public partial class MainForm : Form
    {
        private DataManager? _dataManager;
        private InstanceLauncher? _launcher;
        private HttpApiServer? _apiServer;
        private string _currentProfile = "";

        // UI Components
        private Panel _sidebar = null!;
        private Panel _content = null!;
        private Panel _accountsPanel = null!;
        private Panel _serversPanel = null!;
        private Panel _logsPanel = null!;
        private Panel _settingsPanel = null!;
        private ListBox _logList = null!;
        private FlowLayoutPanel _accountCards = null!;
        private FlowLayoutPanel _serverCards = null!;
        private Label _statusLabel = null!;
        private System.Windows.Forms.Timer _refreshTimer = null!;

        public MainForm()
        {
            InitializeComponent();
            SetupUI();
        }

        private void InitializeComponent()
        {
            this.Text = "Roblox Manager";
            this.Size = new Size(1200, 800);
            this.MinimumSize = new Size(900, 600);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Theme.Background;
            this.ForeColor = Theme.Text;
            this.Font = Theme.Body;

            // Remove default border for modern look
            this.FormBorderStyle = FormBorderStyle.Sizable;
        }

        private void SetupUI()
        {
            // Sidebar
            _sidebar = new Panel
            {
                Dock = DockStyle.Left,
                Width = 200,
                BackColor = Theme.Surface,
                Padding = new Padding(10)
            };

            // Logo/Title
            var titleLabel = new Label
            {
                Text = "Roblox Manager",
                Font = Theme.Title,
                ForeColor = Theme.Accent,
                AutoSize = false,
                Size = new Size(180, 40),
                Location = new Point(10, 15),
                TextAlign = ContentAlignment.MiddleCenter
            };
            _sidebar.Controls.Add(titleLabel);

            // Nav buttons
            var navY = 70;
            CreateNavButton("Accounts", navY, () => ShowPanel(_accountsPanel)); navY += 45;
            CreateNavButton("Servers", navY, () => ShowPanel(_serversPanel)); navY += 45;
            CreateNavButton("Logs", navY, () => ShowPanel(_logsPanel)); navY += 45;
            CreateNavButton("Settings", navY, () => ShowPanel(_settingsPanel)); navY += 45;

            // Status at bottom of sidebar
            _statusLabel = new Label
            {
                Text = "Initializing...",
                Font = Theme.Small,
                ForeColor = Theme.TextMuted,
                Dock = DockStyle.Bottom,
                Height = 60,
                TextAlign = ContentAlignment.MiddleCenter
            };
            _sidebar.Controls.Add(_statusLabel);

            this.Controls.Add(_sidebar);

            // Content area
            _content = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Theme.Background,
                Padding = new Padding(20)
            };
            this.Controls.Add(_content);

            // Create all panels
            CreateAccountsPanel();
            CreateServersPanel();
            CreateLogsPanel();
            CreateSettingsPanel();

            // Show profile selection on load
            this.Load += MainForm_Load;
        }

        private void MainForm_Load(object? sender, EventArgs e)
        {
            // Show profile selection dialog
            var profile = ShowProfileDialog();
            if (string.IsNullOrEmpty(profile))
            {
                Application.Exit();
                return;
            }

            _currentProfile = profile;
            this.Text = $"Roblox Manager - {profile}";

            // Initialize managers
            _dataManager = new DataManager(profile);
            _launcher = new InstanceLauncher(_dataManager);
            _apiServer = new HttpApiServer(_dataManager, _launcher);

            // Hold Roblox mutex
            InstanceLauncher.HoldMutex();

            // Start API server
            _apiServer.OnLog += msg => Log(msg);
            _apiServer.OnHeartbeat += () => BeginInvoke(RefreshAccountCards);
            _apiServer.Start();

            // Start refresh timer
            _refreshTimer = new System.Windows.Forms.Timer { Interval = 5000 };
            _refreshTimer.Tick += (s, e) => RefreshUI();
            _refreshTimer.Start();

            // Initial UI refresh
            RefreshUI();
            ShowPanel(_accountsPanel);

            Log($"[+] Profile: {profile}");
            Log($"[+] Loaded {_dataManager.Accounts.Count} accounts");
            Log($"[+] Loaded {_dataManager.Servers.Count} servers");
            UpdateStatus();
        }

        private string? ShowProfileDialog()
        {
            using var dialog = new Form
            {
                Text = "Select Profile",
                Size = new Size(300, 200),
                StartPosition = FormStartPosition.CenterScreen,
                FormBorderStyle = FormBorderStyle.FixedDialog,
                MaximizeBox = false,
                MinimizeBox = false,
                BackColor = Theme.Surface
            };

            var label = new Label
            {
                Text = "Select a profile:",
                Location = new Point(20, 20),
                Size = new Size(260, 25),
                ForeColor = Theme.Text,
                Font = Theme.Subtitle
            };
            dialog.Controls.Add(label);

            string? selectedProfile = null;

            var unlockBtn = CreateButton("Unlock", 20, 60, 120, 40);
            unlockBtn.Click += (s, e) => { selectedProfile = "Unlock"; dialog.Close(); };
            dialog.Controls.Add(unlockBtn);

            var shakeBtn = CreateButton("Shake", 150, 60, 120, 40);
            shakeBtn.Click += (s, e) => { selectedProfile = "Shake"; dialog.Close(); };
            dialog.Controls.Add(shakeBtn);

            dialog.ShowDialog();
            return selectedProfile;
        }

        private Button CreateNavButton(string text, int y, Action onClick)
        {
            var btn = new Button
            {
                Text = text,
                Location = new Point(10, y),
                Size = new Size(180, 35),
                FlatStyle = FlatStyle.Flat,
                BackColor = Theme.SurfaceLight,
                ForeColor = Theme.Text,
                Font = Theme.Body,
                Cursor = Cursors.Hand
            };
            btn.FlatAppearance.BorderSize = 0;
            btn.FlatAppearance.MouseOverBackColor = Theme.Accent;
            btn.Click += (s, e) => onClick();
            _sidebar.Controls.Add(btn);
            return btn;
        }

        private Button CreateButton(string text, int x, int y, int w, int h)
        {
            return new Button
            {
                Text = text,
                Location = new Point(x, y),
                Size = new Size(w, h),
                FlatStyle = FlatStyle.Flat,
                BackColor = Theme.Accent,
                ForeColor = Theme.Text,
                Font = Theme.Body,
                Cursor = Cursors.Hand
            };
        }

        private void ShowPanel(Panel panel)
        {
            _accountsPanel.Visible = panel == _accountsPanel;
            _serversPanel.Visible = panel == _serversPanel;
            _logsPanel.Visible = panel == _logsPanel;
            _settingsPanel.Visible = panel == _settingsPanel;
        }

        #region Accounts Panel

        private void CreateAccountsPanel()
        {
            _accountsPanel = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Theme.Background,
                Visible = true
            };

            // Header
            var header = new Panel { Dock = DockStyle.Top, Height = 50, BackColor = Theme.Background };

            var titleLabel = new Label
            {
                Text = "Accounts",
                Font = Theme.Title,
                ForeColor = Theme.Text,
                Location = new Point(0, 10),
                AutoSize = true
            };
            header.Controls.Add(titleLabel);

            var addBtn = CreateButton("+ Add Account", 0, 10, 120, 30);
            addBtn.Dock = DockStyle.Right;
            addBtn.Click += (s, e) => AddAccount();
            header.Controls.Add(addBtn);

            var launchAllBtn = CreateButton("Launch All", 0, 10, 100, 30);
            launchAllBtn.Dock = DockStyle.Right;
            launchAllBtn.BackColor = Theme.Success;
            launchAllBtn.Click += async (s, e) => await LaunchAllAccounts();
            header.Controls.Add(launchAllBtn);

            _accountsPanel.Controls.Add(header);

            // Account cards container
            _accountCards = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                AutoScroll = true,
                BackColor = Theme.Background,
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                Padding = new Padding(0, 10, 0, 0)
            };
            _accountsPanel.Controls.Add(_accountCards);

            _content.Controls.Add(_accountsPanel);
        }

        private void RefreshAccountCards()
        {
            if (_dataManager == null) return;

            _accountCards.Controls.Clear();

            foreach (var (name, account) in _dataManager.Accounts.OrderBy(a => a.Value.Priority))
            {
                var card = CreateAccountCard(name, account);
                _accountCards.Controls.Add(card);
            }
        }

        private Panel CreateAccountCard(string name, Account account)
        {
            var card = new Panel
            {
                Size = new Size(_accountCards.Width - 40, 70),
                BackColor = Theme.Surface,
                Margin = new Padding(0, 0, 0, 10),
                Padding = new Padding(15)
            };

            // Status indicator
            var statusDot = new Panel
            {
                Size = new Size(12, 12),
                Location = new Point(15, 29),
                BackColor = account.Status switch
                {
                    AccountStatus.Running => Theme.Online,
                    AccountStatus.Launching => Theme.Launching,
                    _ => Theme.Offline
                }
            };
            card.Controls.Add(statusDot);

            // Account name
            var nameLabel = new Label
            {
                Text = $"[#{account.Priority}] {name}",
                Font = Theme.Subtitle,
                ForeColor = Theme.Text,
                Location = new Point(35, 10),
                AutoSize = true
            };
            card.Controls.Add(nameLabel);

            // Username / Status
            var statusText = account.Status == AccountStatus.Running
                ? $"@{account.Username} • PID {account.ProcessId} • {account.CurrentServer}"
                : account.Status.ToString();

            var statusLabel = new Label
            {
                Text = statusText,
                Font = Theme.Small,
                ForeColor = Theme.TextMuted,
                Location = new Point(35, 35),
                AutoSize = true
            };
            card.Controls.Add(statusLabel);

            // Buttons (right side)
            var btnPanel = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.RightToLeft,
                Dock = DockStyle.Right,
                Width = 200,
                BackColor = Theme.Surface
            };

            if (account.IsRunning)
            {
                var killBtn = new Button
                {
                    Text = "Kill",
                    Size = new Size(60, 30),
                    FlatStyle = FlatStyle.Flat,
                    BackColor = Theme.Error,
                    ForeColor = Theme.Text,
                    Margin = new Padding(5)
                };
                killBtn.Click += (s, e) =>
                {
                    _launcher?.KillInstance(name);
                    RefreshAccountCards();
                };
                btnPanel.Controls.Add(killBtn);
            }
            else
            {
                var launchBtn = new Button
                {
                    Text = "Launch",
                    Size = new Size(70, 30),
                    FlatStyle = FlatStyle.Flat,
                    BackColor = Theme.Success,
                    ForeColor = Theme.Text,
                    Margin = new Padding(5)
                };
                launchBtn.Click += async (s, e) =>
                {
                    await _launcher!.LaunchAccount(name, account.DefaultServer);
                    RefreshAccountCards();
                };
                btnPanel.Controls.Add(launchBtn);
            }

            var editBtn = new Button
            {
                Text = "Edit",
                Size = new Size(50, 30),
                FlatStyle = FlatStyle.Flat,
                BackColor = Theme.SurfaceLight,
                ForeColor = Theme.Text,
                Margin = new Padding(5)
            };
            editBtn.Click += (s, e) => EditAccount(name);
            btnPanel.Controls.Add(editBtn);

            card.Controls.Add(btnPanel);

            return card;
        }

        private void AddAccount()
        {
            using var dialog = new Form
            {
                Text = "Add Account",
                Size = new Size(400, 250),
                StartPosition = FormStartPosition.CenterParent,
                FormBorderStyle = FormBorderStyle.FixedDialog,
                BackColor = Theme.Surface
            };

            var nameLabel = new Label { Text = "Account Name:", Location = new Point(20, 20), ForeColor = Theme.Text };
            var nameBox = new TextBox { Location = new Point(20, 45), Size = new Size(340, 25) };

            var cookieLabel = new Label { Text = "Cookie (.ROBLOSECURITY):", Location = new Point(20, 80), ForeColor = Theme.Text };
            var cookieBox = new TextBox { Location = new Point(20, 105), Size = new Size(340, 25), UseSystemPasswordChar = true };

            var serverLabel = new Label { Text = "Default Server:", Location = new Point(20, 140), ForeColor = Theme.Text };
            var serverBox = new ComboBox { Location = new Point(20, 165), Size = new Size(150, 25), DropDownStyle = ComboBoxStyle.DropDownList };
            foreach (var key in _dataManager!.Servers.Keys)
                serverBox.Items.Add(key);
            if (serverBox.Items.Count > 0) serverBox.SelectedIndex = 0;

            var saveBtn = CreateButton("Save", 280, 165, 80, 30);
            saveBtn.Click += async (s, e) =>
            {
                if (string.IsNullOrWhiteSpace(nameBox.Text) || string.IsNullOrWhiteSpace(cookieBox.Text))
                {
                    MessageBox.Show("Please fill all fields", "Error");
                    return;
                }

                var account = new Account
                {
                    Cookie = cookieBox.Text.Trim(),
                    DefaultServer = serverBox.SelectedItem?.ToString() ?? "farm"
                };

                // Verify cookie and get username
                var username = await VerifyCookie(account.Cookie);
                if (string.IsNullOrEmpty(username))
                {
                    MessageBox.Show("Invalid cookie", "Error");
                    return;
                }
                account.Username = username;

                _dataManager.AddAccount(nameBox.Text.Trim(), account);
                Log($"[+] Added account: {nameBox.Text}");
                RefreshAccountCards();
                dialog.Close();
            };

            dialog.Controls.AddRange(new Control[] { nameLabel, nameBox, cookieLabel, cookieBox, serverLabel, serverBox, saveBtn });
            dialog.ShowDialog();
        }

        private void EditAccount(string name)
        {
            if (!_dataManager!.Accounts.TryGetValue(name, out var account)) return;

            using var dialog = new Form
            {
                Text = $"Edit Account: {name}",
                Size = new Size(400, 250),
                StartPosition = FormStartPosition.CenterParent,
                FormBorderStyle = FormBorderStyle.FixedDialog,
                BackColor = Theme.Surface
            };

            var serverLabel = new Label { Text = "Default Server:", Location = new Point(20, 20), ForeColor = Theme.Text };
            var serverBox = new ComboBox { Location = new Point(20, 45), Size = new Size(150, 25), DropDownStyle = ComboBoxStyle.DropDownList };
            foreach (var key in _dataManager.Servers.Keys)
                serverBox.Items.Add(key);
            serverBox.SelectedItem = account.DefaultServer;

            var priorityLabel = new Label { Text = "Priority (lower = first):", Location = new Point(20, 80), ForeColor = Theme.Text };
            var priorityBox = new NumericUpDown { Location = new Point(20, 105), Size = new Size(80, 25), Minimum = 1, Maximum = 999, Value = account.Priority };

            var saveBtn = CreateButton("Save", 280, 160, 80, 30);
            saveBtn.Click += (s, e) =>
            {
                account.DefaultServer = serverBox.SelectedItem?.ToString() ?? "farm";
                account.Priority = (int)priorityBox.Value;
                _dataManager.Save();
                Log($"[*] Updated account: {name}");
                RefreshAccountCards();
                dialog.Close();
            };

            var deleteBtn = CreateButton("Delete", 190, 160, 80, 30);
            deleteBtn.BackColor = Theme.Error;
            deleteBtn.Click += (s, e) =>
            {
                if (MessageBox.Show($"Delete account '{name}'?", "Confirm", MessageBoxButtons.YesNo) == DialogResult.Yes)
                {
                    _dataManager.RemoveAccount(name);
                    Log($"[-] Deleted account: {name}");
                    RefreshAccountCards();
                    dialog.Close();
                }
            };

            dialog.Controls.AddRange(new Control[] { serverLabel, serverBox, priorityLabel, priorityBox, saveBtn, deleteBtn });
            dialog.ShowDialog();
        }

        private async Task<string?> VerifyCookie(string cookie)
        {
            try
            {
                using var client = new HttpClient();
                client.DefaultRequestHeaders.Add("Cookie", $".ROBLOSECURITY={cookie}");
                var response = await client.GetStringAsync("https://users.roblox.com/v1/users/authenticated");
                var data = Newtonsoft.Json.JsonConvert.DeserializeObject<dynamic>(response);
                return data?.name;
            }
            catch { return null; }
        }

        private async Task LaunchAllAccounts()
        {
            if (_dataManager == null || _launcher == null) return;

            var accounts = _dataManager.Accounts
                .Where(a => !a.Value.IsRunning)
                .OrderBy(a => a.Value.Priority)
                .ToList();

            Log($"[*] Launching {accounts.Count} accounts...");

            foreach (var (name, account) in accounts)
            {
                await _launcher.LaunchAccount(name, account.DefaultServer);
                RefreshAccountCards();
                await Task.Delay(3000); // Stagger launches
            }

            Log($"[+] All accounts launched");
        }

        #endregion

        #region Servers Panel

        private void CreateServersPanel()
        {
            _serversPanel = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Theme.Background,
                Visible = false
            };

            var header = new Panel { Dock = DockStyle.Top, Height = 50, BackColor = Theme.Background };

            var titleLabel = new Label
            {
                Text = "Servers",
                Font = Theme.Title,
                ForeColor = Theme.Text,
                Location = new Point(0, 10),
                AutoSize = true
            };
            header.Controls.Add(titleLabel);

            var addBtn = CreateButton("+ Add Server", 0, 10, 120, 30);
            addBtn.Dock = DockStyle.Right;
            addBtn.Click += (s, e) => AddServer();
            header.Controls.Add(addBtn);

            _serversPanel.Controls.Add(header);

            _serverCards = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                AutoScroll = true,
                BackColor = Theme.Background,
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                Padding = new Padding(0, 10, 0, 0)
            };
            _serversPanel.Controls.Add(_serverCards);

            _content.Controls.Add(_serversPanel);
        }

        private void RefreshServerCards()
        {
            if (_dataManager == null) return;

            _serverCards.Controls.Clear();

            foreach (var (key, server) in _dataManager.Servers)
            {
                var card = CreateServerCard(key, server);
                _serverCards.Controls.Add(card);
            }
        }

        private Panel CreateServerCard(string key, Server server)
        {
            var card = new Panel
            {
                Size = new Size(_serverCards.Width - 40, 60),
                BackColor = Theme.Surface,
                Margin = new Padding(0, 0, 0, 10),
                Padding = new Padding(15)
            };

            var nameLabel = new Label
            {
                Text = $"{server.Name} ({key})",
                Font = Theme.Subtitle,
                ForeColor = Theme.Text,
                Location = new Point(15, 10),
                AutoSize = true
            };
            card.Controls.Add(nameLabel);

            var infoLabel = new Label
            {
                Text = $"Place: {server.PlaceId} • {(server.IsPrivate ? "Private" : "Public")}",
                Font = Theme.Small,
                ForeColor = Theme.TextMuted,
                Location = new Point(15, 32),
                AutoSize = true
            };
            card.Controls.Add(infoLabel);

            return card;
        }

        private void AddServer()
        {
            using var dialog = new Form
            {
                Text = "Add Server",
                Size = new Size(400, 300),
                StartPosition = FormStartPosition.CenterParent,
                FormBorderStyle = FormBorderStyle.FixedDialog,
                BackColor = Theme.Surface
            };

            var keyLabel = new Label { Text = "Server Key:", Location = new Point(20, 20), ForeColor = Theme.Text };
            var keyBox = new TextBox { Location = new Point(20, 45), Size = new Size(150, 25) };

            var nameLabel = new Label { Text = "Display Name:", Location = new Point(20, 80), ForeColor = Theme.Text };
            var nameBox = new TextBox { Location = new Point(20, 105), Size = new Size(200, 25) };

            var placeLabel = new Label { Text = "Place ID:", Location = new Point(20, 140), ForeColor = Theme.Text };
            var placeBox = new TextBox { Location = new Point(20, 165), Size = new Size(150, 25), Text = "133322550157181" };

            var linkLabel = new Label { Text = "Link Code (for private):", Location = new Point(20, 200), ForeColor = Theme.Text };
            var linkBox = new TextBox { Location = new Point(20, 225), Size = new Size(340, 25) };

            var saveBtn = CreateButton("Save", 280, 225, 80, 30);
            saveBtn.Location = new Point(280, 260);
            saveBtn.Click += (s, e) =>
            {
                if (string.IsNullOrWhiteSpace(keyBox.Text) || string.IsNullOrWhiteSpace(nameBox.Text))
                {
                    MessageBox.Show("Key and Name are required", "Error");
                    return;
                }

                var server = new Server
                {
                    Name = nameBox.Text.Trim(),
                    PlaceId = long.TryParse(placeBox.Text, out var pid) ? pid : 133322550157181,
                    LinkCode = linkBox.Text.Trim()
                };

                _dataManager!.AddServer(keyBox.Text.Trim(), server);
                Log($"[+] Added server: {keyBox.Text}");
                RefreshServerCards();
                dialog.Close();
            };

            dialog.Controls.AddRange(new Control[] { keyLabel, keyBox, nameLabel, nameBox, placeLabel, placeBox, linkLabel, linkBox, saveBtn });
            dialog.Size = new Size(400, 340);
            dialog.ShowDialog();
        }

        #endregion

        #region Logs Panel

        private void CreateLogsPanel()
        {
            _logsPanel = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Theme.Background,
                Visible = false
            };

            var header = new Panel { Dock = DockStyle.Top, Height = 50, BackColor = Theme.Background };

            var titleLabel = new Label
            {
                Text = "Logs",
                Font = Theme.Title,
                ForeColor = Theme.Text,
                Location = new Point(0, 10),
                AutoSize = true
            };
            header.Controls.Add(titleLabel);

            var clearBtn = CreateButton("Clear", 0, 10, 80, 30);
            clearBtn.Dock = DockStyle.Right;
            clearBtn.Click += (s, e) => _logList.Items.Clear();
            header.Controls.Add(clearBtn);

            _logsPanel.Controls.Add(header);

            _logList = new ListBox
            {
                Dock = DockStyle.Fill,
                BackColor = Theme.Surface,
                ForeColor = Theme.Text,
                Font = Theme.Mono,
                BorderStyle = BorderStyle.None,
                SelectionMode = SelectionMode.None
            };
            _logsPanel.Controls.Add(_logList);

            _content.Controls.Add(_logsPanel);
        }

        private void Log(string message)
        {
            if (InvokeRequired)
            {
                BeginInvoke(() => Log(message));
                return;
            }

            var timestamp = DateTime.Now.ToString("HH:mm:ss");
            _logList.Items.Add($"[{timestamp}] {message}");
            if (_logList.Items.Count > 500)
                _logList.Items.RemoveAt(0);
            _logList.TopIndex = _logList.Items.Count - 1;

            Console.WriteLine(message);
        }

        #endregion

        #region Settings Panel

        private void CreateSettingsPanel()
        {
            _settingsPanel = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Theme.Background,
                Visible = false
            };

            var header = new Panel { Dock = DockStyle.Top, Height = 50, BackColor = Theme.Background };

            var titleLabel = new Label
            {
                Text = "Settings",
                Font = Theme.Title,
                ForeColor = Theme.Text,
                Location = new Point(0, 10),
                AutoSize = true
            };
            header.Controls.Add(titleLabel);
            _settingsPanel.Controls.Add(header);

            var settingsContent = new Panel { Dock = DockStyle.Fill, BackColor = Theme.Background };

            var y = 20;

            var heartbeatCheck = new CheckBox
            {
                Text = "Require Lua Heartbeat",
                Location = new Point(20, y),
                ForeColor = Theme.Text,
                AutoSize = true,
                Checked = true
            };
            settingsContent.Controls.Add(heartbeatCheck);
            y += 35;

            var autoRejoinCheck = new CheckBox
            {
                Text = "Auto Rejoin (Watchdog)",
                Location = new Point(20, y),
                ForeColor = Theme.Text,
                AutoSize = true
            };
            settingsContent.Controls.Add(autoRejoinCheck);
            y += 50;

            var killAllBtn = CreateButton("Kill All & Reset", 20, y, 150, 35);
            killAllBtn.BackColor = Theme.Error;
            killAllBtn.Click += (s, e) =>
            {
                _launcher?.KillAllInstances();
                InstanceLauncher.HoldMutex();
                Log("[*] Killed all instances and reset mutex");
                RefreshAccountCards();
            };
            settingsContent.Controls.Add(killAllBtn);

            _settingsPanel.Controls.Add(settingsContent);
            _content.Controls.Add(_settingsPanel);
        }

        #endregion

        private void RefreshUI()
        {
            if (InvokeRequired)
            {
                BeginInvoke(RefreshUI);
                return;
            }

            RefreshAccountCards();
            RefreshServerCards();
            UpdateStatus();
        }

        private void UpdateStatus()
        {
            if (_dataManager == null) return;

            var running = _dataManager.Accounts.Values.Count(a => a.IsRunning);
            var total = _dataManager.Accounts.Count;
            var heartbeats = _apiServer?.PlayerReports.Count ?? 0;

            _statusLabel.Text = $"Accounts: {running}/{total}\nHeartbeats: {heartbeats}\nAPI: :8080";
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            _refreshTimer?.Stop();
            _apiServer?.Stop();
            base.OnFormClosing(e);
        }
    }
}
