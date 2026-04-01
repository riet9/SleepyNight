using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows.Forms;

namespace SleepyNight.Desktop;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        var root = AppPaths.FindRoot();
        Application.Run(new DashboardForm(root));
    }
}

internal sealed class GlassPanel : Panel
{
    public Color FillColor { get; set; } = Color.FromArgb(132, 21, 33, 72);
    public Color BorderColor { get; set; } = Color.FromArgb(46, 166, 237, 255);
    public int CornerRadius { get; set; } = 10;

    public GlassPanel()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;

        if (BackgroundImage is not null)
        {
            e.Graphics.DrawImage(BackgroundImage, ClientRectangle);
        }
        else
        {
            PaintAncestorBackground(e.Graphics);
        }

        using var path = CreateRoundedPath(new Rectangle(0, 0, Math.Max(1, Width - 1), Math.Max(1, Height - 1)), CornerRadius);
        using var brush = new SolidBrush(FillColor);
        e.Graphics.FillPath(brush, path);

        if (BorderColor.A > 0)
        {
            using var pen = new Pen(BorderColor, 1f);
            e.Graphics.DrawPath(pen, path);
        }
    }

    private void PaintAncestorBackground(Graphics graphics)
    {
        Control? current = Parent;
        var offsetX = -Left;
        var offsetY = -Top;

        while (current is not null)
        {
            if (current.BackgroundImage is not null)
            {
                graphics.DrawImage(current.BackgroundImage, new Rectangle(offsetX, offsetY, current.ClientSize.Width, current.ClientSize.Height));
                return;
            }

            offsetX -= current.Left;
            offsetY -= current.Top;
            current = current.Parent;
        }

        graphics.Clear(Color.FromArgb(14, 22, 46));
    }

    private static GraphicsPath CreateRoundedPath(Rectangle bounds, int radius)
    {
        var path = new GraphicsPath();
        var diameter = Math.Max(0, radius * 2);

        if (diameter <= 0)
        {
            path.AddRectangle(bounds);
            path.CloseFigure();
            return path;
        }

        path.AddArc(bounds.X, bounds.Y, diameter, diameter, 180, 90);
        path.AddArc(bounds.Right - diameter, bounds.Y, diameter, diameter, 270, 90);
        path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(bounds.X, bounds.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }
}
internal sealed class DashboardForm : Form
{
    private readonly string _root;
    private readonly System.Windows.Forms.Timer _timer = new();
    private readonly NotifyIcon _notifyIcon = new();
    private readonly Icon? _appIcon;

    private readonly Color _appBackdrop = Color.FromArgb(14, 22, 46);
    private readonly Color _shell = Color.FromArgb(19, 30, 66);
    private readonly Color _shellSoft = Color.FromArgb(27, 42, 88);
    private readonly Color _shellSoftAlt = Color.FromArgb(31, 49, 102);
    private readonly Color _line = Color.FromArgb(82, 104, 163);
    private readonly Color _card = Color.FromArgb(29, 44, 91);
    private readonly Color _cardAlt = Color.FromArgb(34, 53, 107);
    private readonly Color _cyan = Color.FromArgb(97, 220, 255);
    private readonly Color _cyanSoft = Color.FromArgb(166, 237, 255);
    private readonly Color _white = Color.FromArgb(243, 247, 255);
    private readonly Color _muted = Color.FromArgb(173, 185, 223);
    private readonly Color _success = Color.FromArgb(80, 187, 142);
    private readonly Color _danger = Color.FromArgb(186, 74, 92);
    private readonly Color _warning = Color.FromArgb(234, 195, 94);

    private GlassPanel? _heroCard;
    private GlassPanel? _countdownCard;
    private GlassPanel? _statusCard;

    private readonly Label _heroTitle = new();
    private readonly Label _heroSubtitle = new();
    private readonly Label _heroMeta = new();
    private readonly Label _phasePill = new();
    private readonly Label _countdownValue = new();
    private readonly Label _countdownCaption = new();
    private readonly Label _windowTitle = new();
    private readonly Label _windowMeta = new();
    private readonly Label _windowBody = new();
    private readonly Label _agentState = new();
    private readonly Label _autostartState = new();
    private readonly Label _skipState = new();
    private readonly Label _modeState = new();
    private readonly Label _watchdogState = new();
    private readonly Label _footerHint = new();
    private readonly Label _testModePill = new();
    private readonly Label _healthHeartbeatState = new();
    private readonly Label _healthActionState = new();
    private readonly Label _testModeState = new();
    private readonly Label _scheduleAvailabilityState = new();
    private readonly Label _tonightSummaryState = new();
    private Button? _startAgentButton;
    private Button? _stopAgentButton;
    private Button? _testButton;
    private Button? _stopTestButton;
    private Button? _installAutostartButton;
    private Button? _removeAutostartButton;
    private Button? _repairAutostartButton;
    private Button? _skipTonightButton;
    private Button? _clearSkipButton;

    private readonly CheckBox _enabled = new();
    private readonly CheckBox _weekendSchedule = new();
    private readonly DateTimePicker _weekdayStart = CreateTimePicker();
    private readonly DateTimePicker _weekdayEnd = CreateTimePicker();
    private readonly DateTimePicker _weekendStart = CreateTimePicker();
    private readonly DateTimePicker _weekendEnd = CreateTimePicker();
    private readonly TextBox _warnings = new();
    private readonly ComboBox _mode = new();
    private readonly NumericUpDown _grace = new();
    private readonly NumericUpDown _lockSeconds = new();
    private readonly CheckBox _logging = new();
    private readonly TextBox _titleBox = new();
    private readonly TextBox _emergencyCode = new();

    private bool _allowExit;

    public DashboardForm(string root)
    {
        _root = root;
        Text = "SleepyNight";
        BackColor = _appBackdrop;
        ClientSize = new Size(1560, 980);
        MinimumSize = new Size(1500, 940);
        FormBorderStyle = FormBorderStyle.Sizable;
        MaximizeBox = true;
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 9.5f);
        _appIcon = LoadAppIcon(_root);
        if (_appIcon is not null)
        {
            Icon = _appIcon;
        }

        _timer.Interval = 5000;

        BuildShell();
        ConfigureTray();
        RunSafe(LoadConfigIntoControls, "Could not load the current settings.");
        RunSafe(RefreshDashboard, "Could not refresh the dashboard.");

        _timer.Tick += (_, _) => RunSafe(RefreshDashboard, "Could not refresh the dashboard.");
        _timer.Start();
    }

    private void BuildShell()
    {
        var shell = new Panel
        {
            Left = 0,
            Top = 0,
            Width = ClientSize.Width,
            Height = ClientSize.Height,
            Dock = DockStyle.Fill,
            BackColor = _shell
        };
        var shellImagePath = Path.Combine(_root, "Images", "sn_bg.png");
        if (File.Exists(shellImagePath))
        {
            using var shellImage = Image.FromFile(shellImagePath);
            shell.BackgroundImage = new Bitmap(shellImage);
            shell.BackgroundImageLayout = ImageLayout.Stretch;
        }
        Controls.Add(shell);

        var topBar = new GlassPanel
        {
            Left = 0,
            Top = 0,
            Width = shell.Width,
            Height = 82,
            FillColor = Color.FromArgb(138, 12, 20, 46),
            BorderColor = Color.FromArgb(0, 0, 0, 0),
            Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right
        };
        shell.Controls.Add(topBar);

        var brandTitle = CreateLabel("SleepyNight", 22, 8, 320, 50, _white, 24, FontStyle.Bold, "Georgia");
        topBar.Controls.Add(brandTitle);
        var brandSubtitle = CreateLabel("Bedtime protection dashboard", 24, 56, 300, 18, _muted, 9, FontStyle.Regular);
        topBar.Controls.Add(brandSubtitle);
        var topMeta = CreateLabel("Agent, schedule, quick test, autostart", 970, 28, 280, 18, _cyanSoft, 9, FontStyle.Bold);
        topMeta.TextAlign = ContentAlignment.MiddleRight;
        topMeta.Anchor = AnchorStyles.Top | AnchorStyles.Right;
        topBar.Controls.Add(topMeta);

        var leftMenu = new GlassPanel
        {
            Left = 0,
            Top = 82,
            Width = 248,
            Height = shell.Height - 82,
            FillColor = Color.FromArgb(102, 10, 18, 42),
            BorderColor = Color.FromArgb(0, 0, 0, 0),
            Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left
        };
        shell.Controls.Add(leftMenu);
        BuildLeftMenu(leftMenu);

        var centerPanel = new GlassPanel
        {
            Left = 248,
            Top = 82,
            Width = shell.Width - 248 - 334,
            Height = shell.Height - 82,
            FillColor = Color.FromArgb(44, 10, 18, 40),
            BorderColor = Color.FromArgb(0, 0, 0, 0),
            Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right
        };
        shell.Controls.Add(centerPanel);
        BuildCenterPanel(centerPanel);

        var rightRail = new GlassPanel
        {
            Left = shell.Width - 334,
            Top = 82,
            Width = 320,
            Height = shell.Height - 82,
            FillColor = Color.FromArgb(118, 18, 28, 60),
            BorderColor = Color.FromArgb(0, 0, 0, 0),
            Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Right
        };
        shell.Controls.Add(rightRail);
        BuildRightRail(rightRail);

        Resize += (_, _) =>
        {
            if (WindowState == FormWindowState.Minimized)
            {
                HideToTray();
            }
        };

        FormClosing += (_, e) =>
        {
            if (_allowExit)
            {
                _notifyIcon.Visible = false;
                return;
            }

            e.Cancel = true;
            HideToTray();
        };
    }

    private void BuildLeftMenu(Panel parent)
    {
        parent.Controls.Add(CreateLabel("Tonight", 20, 22, 160, 20, _muted, 9, FontStyle.Bold));

        var tonightCard = CreateCard(18, 52, 216, 258, _cardAlt);
        tonightCard.Controls.Add(CreateLabel("What happens tonight", 16, 16, 170, 18, _white, 10, FontStyle.Bold));
        _tonightSummaryState.Location = new Point(16, 44);
        _tonightSummaryState.Size = new Size(184, 194);
        _tonightSummaryState.ForeColor = _muted;
        _tonightSummaryState.Font = new Font("Segoe UI", 9.1f);
        tonightCard.Controls.Add(_tonightSummaryState);
        parent.Controls.Add(tonightCard);

        var ideaCard = CreateCard(18, 328, 216, 120, _card);
        ideaCard.Controls.Add(CreateLabel("Main idea", 16, 16, 140, 18, _white, 10, FontStyle.Bold));
        ideaCard.Controls.Add(CreateLabel("After 20:30 the computer should stop being a comfortable place to linger.", 16, 44, 184, 60, _muted, 9.1f, FontStyle.Regular));
        parent.Controls.Add(ideaCard);

        var useCard = CreateCard(18, 466, 216, 150, _cardAlt);
        useCard.Controls.Add(CreateLabel("Quick use", 16, 16, 140, 18, _white, 10, FontStyle.Bold));
        useCard.Controls.Add(CreateLabel("1. Set the bedtime window\n2. Save changes\n3. Keep agent and autostart on\n4. Use quick test for safe checks", 16, 44, 184, 92, _cyanSoft, 9.1f, FontStyle.Regular));
        parent.Controls.Add(useCard);
    }

    private void BuildCenterPanel(Panel parent)
    {
        _heroCard = CreateCard(24, 24, 700, 184, _cardAlt);
        var heroCard = _heroCard;
        heroCard.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        var heroImagePath = Path.Combine(_root, "Images", "sn_bg.png");
        if (File.Exists(heroImagePath))
        {
            using var heroImage = Image.FromFile(heroImagePath);
            heroCard.BackgroundImage = new Bitmap(heroImage);
            heroCard.BackgroundImageLayout = ImageLayout.Stretch;
        }

        heroCard.Paint += (_, e) =>
        {
            using var overlay = new SolidBrush(heroCard.BackgroundImage is null
                ? Color.FromArgb(42, 34, 74)
                : Color.FromArgb(142, 16, 24, 50));
            e.Graphics.FillRectangle(overlay, heroCard.ClientRectangle);
            using var glowPen = new Pen(Color.FromArgb(56, _cyan));
            e.Graphics.DrawRectangle(glowPen, 0, 0, heroCard.Width - 1, heroCard.Height - 1);
        };

        _heroTitle.Text = "Bedtime protection";
        _heroTitle.Location = new Point(22, 14);
        _heroTitle.Size = new Size(360, 34);
        _heroTitle.ForeColor = _white;
        _heroTitle.BackColor = Color.Transparent;
        _heroTitle.Font = new Font("Georgia", 20, FontStyle.Bold);
        heroCard.Controls.Add(_heroTitle);

        _heroSubtitle.Text = "Until next restriction: --";
        _heroSubtitle.Location = new Point(24, 58);
        _heroSubtitle.Size = new Size(646, 24);
        _heroSubtitle.ForeColor = Color.FromArgb(232, 238, 255);
        _heroSubtitle.BackColor = Color.Transparent;
        _heroSubtitle.Font = new Font("Segoe UI Semibold", 10f);
        _heroSubtitle.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        heroCard.Controls.Add(_heroSubtitle);

        _heroMeta.Text = "Window: --";
        _heroMeta.Location = new Point(24, 88);
        _heroMeta.Size = new Size(646, 20);
        _heroMeta.ForeColor = _cyanSoft;
        _heroMeta.BackColor = Color.Transparent;
        _heroMeta.Font = new Font("Segoe UI", 9.1f);
        _heroMeta.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        heroCard.Controls.Add(_heroMeta);

        _phasePill.Text = "ALLOWED NOW";
        _phasePill.Location = new Point(24, 128);
        _phasePill.Size = new Size(160, 34);
        _phasePill.TextAlign = ContentAlignment.MiddleCenter;
        _phasePill.Font = new Font("Segoe UI", 10, FontStyle.Bold);
        heroCard.Controls.Add(_phasePill);

        _testModePill.Text = "TEST MODE";
        _testModePill.Location = new Point(194, 128);
        _testModePill.Size = new Size(126, 34);
        _testModePill.TextAlign = ContentAlignment.MiddleCenter;
        _testModePill.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
        _testModePill.BackColor = _warning;
        _testModePill.ForeColor = _shell;
        _testModePill.Visible = false;
        heroCard.Controls.Add(_testModePill);
        parent.Controls.Add(heroCard);

        var scheduleCard = CreateCard(24, 228, 700, 222, _card);
        scheduleCard.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        scheduleCard.Controls.Add(CreateLabel("Restriction schedule", 18, 16, 200, 20, _white, 11, FontStyle.Bold));
        scheduleCard.Controls.Add(CreateLabel("Weekdays", 18, 64, 100, 18, _muted, 9, FontStyle.Bold));
        scheduleCard.Controls.Add(CreateLabel("Weekends", 18, 110, 100, 18, _muted, 9, FontStyle.Bold));
        scheduleCard.Controls.Add(CreateLabel("Warnings", 18, 158, 100, 18, _muted, 9, FontStyle.Bold));

        _enabled.Text = "Protection enabled";
        _enabled.Location = new Point(498, 18);
        _enabled.Width = 170;
        StyleCheckBox(_enabled, _card);

        _weekendSchedule.Text = "Use a separate weekend schedule";
        _weekendSchedule.Location = new Point(406, 156);
        _weekendSchedule.Width = 250;
        StyleCheckBox(_weekendSchedule, _card);

        PlaceInput(scheduleCard, _weekdayStart, 148, 58, 104);
        PlaceInput(scheduleCard, _weekdayEnd, 296, 58, 104);
        PlaceInput(scheduleCard, _weekendStart, 148, 104, 104);
        PlaceInput(scheduleCard, _weekendEnd, 296, 104, 104);

        _warnings.Left = 148;
        _warnings.Top = 154;
        _warnings.Width = 120;
        StyleInput(_warnings);

        scheduleCard.Controls.AddRange(new Control[]
        {
            _enabled,
            _weekendSchedule,
            _weekdayStart,
            _weekdayEnd,
            _weekendStart,
            _weekendEnd,
            _warnings,
            CreateLabel("to", 266, 62, 20, 18, _muted, 9, FontStyle.Regular),
            CreateLabel("to", 266, 108, 20, 18, _muted, 9, FontStyle.Regular)
        });
        parent.Controls.Add(scheduleCard);

        var behaviorCard = CreateCard(24, 470, 700, 300, _card);
        behaviorCard.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        behaviorCard.Controls.Add(CreateLabel("Behavior and controls", 18, 16, 240, 20, _white, 11, FontStyle.Bold));
        behaviorCard.Controls.Add(CreateLabel("SETTINGS", 18, 40, 80, 14, _muted, 8.4f, FontStyle.Bold));

        _mode.Left = 18;
        _mode.Top = 66;
        _mode.Width = 250;
        _mode.DropDownStyle = ComboBoxStyle.DropDownList;
        _mode.DisplayMember = "Name";
        _mode.ValueMember = "Value";
        _mode.Items.AddRange(new object[]
        {
            new ModeOption("Warn only", "warn_only"),
            new ModeOption("Lock only", "lock_only"),
            new ModeOption("Lock and shut down", "lock_shutdown"),
            new ModeOption("Lock and sign out", "lock_logoff")
        });
        StyleInput(_mode);

        _grace.Left = 286;
        _grace.Top = 66;
        _grace.Width = 92;
        _grace.Minimum = 0;
        _grace.Maximum = 120;
        StyleInput(_grace);

        _lockSeconds.Left = 394;
        _lockSeconds.Top = 66;
        _lockSeconds.Width = 104;
        _lockSeconds.Minimum = 5;
        _lockSeconds.Maximum = 300;
        StyleInput(_lockSeconds);

        _logging.Text = "Write log";
        _logging.Location = new Point(18, 110);
        _logging.Width = 120;
        StyleCheckBox(_logging, _card);

        _titleBox.Left = 18;
        _titleBox.Top = 158;
        _titleBox.Width = 250;
        StyleInput(_titleBox);

        _emergencyCode.Left = 286;
        _emergencyCode.Top = 158;
        _emergencyCode.Width = 212;
        _emergencyCode.UseSystemPasswordChar = true;
        StyleInput(_emergencyCode);

        var saveButton = CreateActionButton("Save", 18, 214, 96, _cyan, _shell, (_, _) => RunSafe(SaveConfig, "Could not save the settings."));
        _startAgentButton = CreateActionButton("Start agent", 126, 214, 120, _cyan, _shell, (_, _) => RunSafe(StartAgent, "Could not start the agent."));
        _stopAgentButton = CreateActionButton("Stop agent", 258, 214, 120, _danger, _white, (_, _) => RunSafe(ConfirmAndStopAgent, "Could not stop the agent."));
        _testButton = CreateActionButton("Test in 2 min", 390, 214, 136, _shellSoftAlt, _white, (_, _) => RunSafe(CreateQuickTestWindow, "Could not create a quick test."));
        _stopTestButton = CreateActionButton("Stop test", 538, 214, 108, _warning, _shell, (_, _) => RunSafe(ConfirmAndStopTest, "Could not restore the main schedule."));

        behaviorCard.Controls.AddRange(new Control[]
        {
            CreateLabel("Mode", 18, 48, 80, 14, _muted, 9, FontStyle.Bold),
            CreateLabel("Delay (min)", 286, 48, 80, 14, _muted, 9, FontStyle.Bold),
            CreateLabel("Check sec", 394, 48, 90, 14, _muted, 9, FontStyle.Bold),
            CreateLabel("Notification title", 18, 140, 140, 14, _muted, 9, FontStyle.Bold),
            CreateLabel("Emergency code", 286, 140, 120, 14, _muted, 9, FontStyle.Bold),
            CreateLabel("ACTIONS", 18, 194, 80, 14, _muted, 8.4f, FontStyle.Bold),
            _mode,
            _grace,
            _lockSeconds,
            _logging,
            _titleBox,
            _emergencyCode,
            saveButton,
            _startAgentButton,
            _stopAgentButton,
            _testButton,
            _stopTestButton,
            CreateLabel("Quick test creates a short safe window for checking warnings and locking without waiting for the real bedtime.", 18, 258, 640, 24, _muted, 8.8f, FontStyle.Regular)
        });
        parent.Controls.Add(behaviorCard);
    }

    private void BuildRightRail(Panel parent)
    {
        parent.Controls.Add(CreateLabel("Control center", 18, 24, 220, 24, _white, 15, FontStyle.Regular));

        _countdownCard = CreateCard(16, 68, 288, 148, _card);
        var countdownCard = _countdownCard;
        countdownCard.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        countdownCard.Controls.Add(CreateLabel("Time horizon", 18, 10, 200, 16, _muted, 8.5f, FontStyle.Bold));
        countdownCard.Controls.Add(CreateLabel("HH:MM:SS", 18, 30, 200, 16, _cyanSoft, 8.7f, FontStyle.Bold));

        _countdownValue.Text = "--";
        _countdownValue.Location = new Point(18, 52);
        _countdownValue.Size = new Size(248, 42);
        _countdownValue.ForeColor = _white;
        _countdownValue.Font = new Font("Georgia", 19f, FontStyle.Bold);

        _countdownCaption.Text = "Waiting for schedule data";
        _countdownCaption.Location = new Point(18, 104);
        _countdownCaption.Size = new Size(248, 22);
        _countdownCaption.ForeColor = _cyanSoft;
        _countdownCaption.Font = new Font("Segoe UI", 9.2f);

        countdownCard.Controls.AddRange(new Control[] { _countdownValue, _countdownCaption });
        parent.Controls.Add(countdownCard);

        var windowCard = CreateCard(16, 230, 288, 118, _cardAlt);
        windowCard.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        windowCard.Controls.Add(CreateLabel("UPCOMING WINDOW", 18, 12, 200, 16, _muted, 8.5f, FontStyle.Bold));

        _windowTitle.Location = new Point(18, 34);
        _windowTitle.Size = new Size(248, 22);
        _windowTitle.ForeColor = _white;
        _windowTitle.Font = new Font("Segoe UI Semibold", 11f);

        _windowMeta.Location = new Point(18, 58);
        _windowMeta.Size = new Size(248, 18);
        _windowMeta.ForeColor = _cyanSoft;
        _windowMeta.Font = new Font("Segoe UI", 9f);

        _windowBody.Location = new Point(18, 80);
        _windowBody.Size = new Size(256, 28);
        _windowBody.ForeColor = _muted;
        _windowBody.Font = new Font("Segoe UI", 8.8f);

        windowCard.Controls.AddRange(new Control[] { _windowTitle, _windowMeta, _windowBody });
        parent.Controls.Add(windowCard);

        _statusCard = CreateCard(16, 364, 288, 176, _card);
        var statusCard = _statusCard;
        statusCard.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        statusCard.Controls.Add(CreateLabel("SYSTEM HEALTH", 18, 12, 200, 16, _muted, 8.5f, FontStyle.Bold));

        _agentState.Location = new Point(18, 34);
        _agentState.Size = new Size(248, 18);
        _agentState.ForeColor = _white;
        _agentState.Font = new Font("Segoe UI Semibold", 10f);

        _autostartState.Location = new Point(18, 58);
        _autostartState.Size = new Size(248, 18);
        _autostartState.ForeColor = _cyanSoft;

        _healthHeartbeatState.Location = new Point(18, 82);
        _healthHeartbeatState.Size = new Size(248, 18);
        _healthHeartbeatState.ForeColor = _muted;
        _healthHeartbeatState.Font = new Font("Segoe UI", 9f);

        _watchdogState.Location = new Point(18, 104);
        _watchdogState.Size = new Size(248, 18);
        _watchdogState.ForeColor = _cyanSoft;
        _watchdogState.Font = new Font("Segoe UI Semibold", 8.9f);

        _modeState.Location = new Point(18, 126);
        _modeState.Size = new Size(248, 18);
        _modeState.ForeColor = _muted;

        _healthActionState.Location = new Point(18, 148);
        _healthActionState.Size = new Size(256, 18);
        _healthActionState.ForeColor = _muted;
        _healthActionState.Font = new Font("Segoe UI", 8.3f);

        statusCard.Controls.AddRange(new Control[] { _agentState, _autostartState, _healthHeartbeatState, _watchdogState, _modeState, _healthActionState });
        parent.Controls.Add(statusCard);

        var policyCard = CreateCard(16, 556, 288, 116, _cardAlt);
        policyCard.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        policyCard.Controls.Add(CreateLabel("NIGHT RULES", 18, 12, 200, 16, _muted, 8.5f, FontStyle.Bold));

        _testModeState.Location = new Point(18, 34);
        _testModeState.Size = new Size(256, 18);
        _testModeState.ForeColor = _white;
        _testModeState.Font = new Font("Segoe UI Semibold", 9.5f);

        _skipState.Location = new Point(18, 60);
        _skipState.Size = new Size(256, 18);
        _skipState.ForeColor = _cyanSoft;

        _scheduleAvailabilityState.Location = new Point(18, 86);
        _scheduleAvailabilityState.Size = new Size(256, 18);
        _scheduleAvailabilityState.ForeColor = _muted;

        policyCard.Controls.AddRange(new Control[] { _testModeState, _skipState, _scheduleAvailabilityState });
        parent.Controls.Add(policyCard);

        var actionCard = CreateCard(16, 688, 288, 202, _card);
        actionCard.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        actionCard.Controls.Add(CreateLabel("FAST ACTIONS", 18, 12, 200, 16, _muted, 8.5f, FontStyle.Bold));
        _installAutostartButton = CreateActionButton("Install autostart", 16, 36, 256, _cardAlt, _white, (_, _) => RunSafe(() => RunInstaller(false), "Could not install autostart."));
        _removeAutostartButton = CreateActionButton("Remove autostart", 16, 68, 256, _cardAlt, _white, (_, _) => RunSafe(ConfirmAndRemoveAutostart, "Could not remove autostart."));
        _repairAutostartButton = CreateActionButton("Repair autostart", 16, 100, 256, _cyan, _shell, (_, _) => RunSafe(RepairAutostart, "Could not repair autostart."));
        _skipTonightButton = CreateActionButton("Skip tonight", 16, 132, 124, _shellSoftAlt, _white, (_, _) => RunSafe(SkipTonight, "Could not enable skip."));
        _clearSkipButton = CreateActionButton("Clear skip", 148, 132, 124, _shellSoftAlt, _white, (_, _) => RunSafe(ConfirmAndClearSkip, "Could not clear the skip."));
        var openLogButton = CreateActionButton("Open log", 16, 164, 124, _shellSoftAlt, _white, (_, _) => RunSafe(OpenLog, "Could not open the log."));
        var trayButton = CreateActionButton("To tray", 148, 164, 124, _shell, _white, (_, _) => HideToTray());
        actionCard.Controls.AddRange(new Control[] { _installAutostartButton, _removeAutostartButton, _repairAutostartButton, _skipTonightButton, _clearSkipButton, openLogButton, trayButton });
        parent.Controls.Add(actionCard);
    }

    private void ConfigureTray()
    {
        _notifyIcon.Icon = _appIcon ?? SystemIcons.Information;
        _notifyIcon.Text = "SleepyNight";
        _notifyIcon.Visible = true;
        _notifyIcon.DoubleClick += (_, _) => ShowFromTray();

        var menu = new ContextMenuStrip();
        menu.Items.Add("Open", null, (_, _) => ShowFromTray());
        menu.Items.Add("Start agent", null, (_, _) => RunSafe(StartAgent, "Could not start the agent."));
        menu.Items.Add("Stop agent", null, (_, _) => RunSafe(ConfirmAndStopAgent, "Could not stop the agent."));
        menu.Items.Add("Test in 2 min", null, (_, _) => RunSafe(CreateQuickTestWindow, "Could not create a quick test."));
        menu.Items.Add("Stop test", null, (_, _) => RunSafe(ConfirmAndStopTest, "Could not restore the main schedule."));
        menu.Items.Add("-");
        menu.Items.Add("Exit", null, (_, _) => ExitApp());
        _notifyIcon.ContextMenuStrip = menu;
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        _appIcon?.Dispose();
        base.OnFormClosed(e);
    }

    private static Icon? LoadAppIcon(string root)
    {
        var iconPath = AppPaths.AppIconPath(root);
        if (!File.Exists(iconPath))
        {
            return null;
        }

        try
        {
            return new Icon(iconPath);
        }
        catch
        {
            return null;
        }
    }

    private static DateTimePicker CreateTimePicker() => new()
    {
        Format = DateTimePickerFormat.Custom,
        CustomFormat = "HH:mm",
        ShowUpDown = true,
        Width = 98
    };

    private Button CreateNavButton(string text, int top, bool active)
    {
        var button = new Button
        {
            Text = text,
            Left = 12,
            Top = top,
            Width = 48,
            Height = 44,
            BackColor = active ? _cyan : _shellSoft,
            ForeColor = active ? _shell : _white,
            FlatStyle = FlatStyle.Flat,
            Cursor = Cursors.Hand,
            Font = new Font("Segoe UI", 9, FontStyle.Bold)
        };
        button.FlatAppearance.BorderColor = Color.FromArgb(92, 118, 146, 208);
        button.FlatAppearance.BorderSize = 1;
        button.FlatAppearance.MouseOverBackColor = ControlPaint.Light(button.BackColor, 0.08f);
        button.FlatAppearance.MouseDownBackColor = ControlPaint.Dark(button.BackColor, 0.05f);
        return button;
    }

    private GlassPanel CreateCard(int left, int top, int width, int height, Color backColor) => new()
    {
        Left = left,
        Top = top,
        Width = width,
        Height = height,
        FillColor = Color.FromArgb(198, backColor.R, backColor.G, backColor.B),
        BorderColor = Color.FromArgb(18, _cyan),
        CornerRadius = 14
    };

    private static Label CreateLabel(string text, int left, int top, int width, int height, Color color, float size, FontStyle style, string family = "Segoe UI") => new()
    {
        Text = text,
        Left = left,
        Top = top,
        Width = width,
        Height = height,
        ForeColor = color,
        BackColor = Color.Transparent,
        Font = new Font(family, size, style)
    };

    private Button CreateActionButton(string text, int left, int top, int width, Color back, Color fore, EventHandler onClick)
    {
        var button = new Button
        {
            Text = text,
            Left = left,
            Top = top,
            Width = width,
            Height = 30,
            BackColor = back,
            ForeColor = fore,
            FlatStyle = FlatStyle.Flat,
            Cursor = Cursors.Hand,
            Font = new Font("Segoe UI Semibold", 9.2f)
        };
        button.FlatAppearance.BorderColor = Color.FromArgb(92, 118, 146, 208);
        button.FlatAppearance.BorderSize = 1;
        button.FlatAppearance.MouseOverBackColor = ControlPaint.Light(button.BackColor, 0.08f);
        button.FlatAppearance.MouseDownBackColor = ControlPaint.Dark(button.BackColor, 0.05f);
        button.Click += onClick;
        return button;
    }

    private void PlaceInput(Control parent, Control control, int left, int top, int width)
    {
        control.Left = left;
        control.Top = top;
        control.Width = width;
        StyleInput(control);
        parent.Controls.Add(control);
    }

    private void StyleCheckBox(CheckBox checkBox, Color background)
    {
        checkBox.BackColor = Color.Transparent;
        checkBox.ForeColor = _white;
        checkBox.Font = new Font("Segoe UI", 9f);
        checkBox.UseVisualStyleBackColor = false;
    }

    private void StyleInput(Control control)
    {
        control.BackColor = Color.FromArgb(234, 239, 249);
        control.ForeColor = _shell;
        control.Font = new Font("Segoe UI", 9.3f);
    }

    private void RunSafe(Action action, string message)
    {
        try
        {
            action();
        }
        catch (Exception ex)
        {
            Logger.Append(_root, $"Desktop UI error: {ex}");
            MessageBox.Show(this, message + Environment.NewLine + Environment.NewLine + ex.Message, "SleepyNight", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    private void LoadConfigIntoControls()
    {
        var config = ConfigStore.Load(_root);

        _enabled.Checked = config.Enabled;
        _weekendSchedule.Checked = config.Schedule.UseWeekendSchedule;
        _weekdayStart.Value = TodayAt(config.Schedule.Weekdays.Start);
        _weekdayEnd.Value = TodayAt(config.Schedule.Weekdays.End);
        _weekendStart.Value = TodayAt(config.Schedule.Weekends.Start);
        _weekendEnd.Value = TodayAt(config.Schedule.Weekends.End);
        _warnings.Text = string.Join(", ", config.WarningMinutes ?? Array.Empty<int>());
        _grace.Value = ClampDecimal(config.GraceMinutes, _grace.Minimum, _grace.Maximum);
        _lockSeconds.Value = ClampDecimal(config.LockCheckSeconds, _lockSeconds.Minimum, _lockSeconds.Maximum);
        _logging.Checked = config.LoggingEnabled;
        _titleBox.Text = config.MessageTitle ?? "SleepyNight";
        _emergencyCode.Text = config.EmergencyCode ?? string.Empty;

        var targetMode = config.EnforcementMode ?? "lock_shutdown";
        var selected = _mode.Items.Cast<ModeOption>().FirstOrDefault(item => item.Value == targetMode) ?? _mode.Items.Cast<ModeOption>().First();
        _mode.SelectedItem = selected;
    }

    private void SaveConfig()
    {
        var current = ConfigStore.Load(_root);
        var state = StateStore.Load(_root);
        var now = DateTimeOffset.Now;
        var updatedUseWeekendSchedule = _weekendSchedule.Checked;
        var updatedWeekdayStart = _weekdayStart.Value.ToString("HH:mm");
        var updatedWeekdayEnd = _weekdayEnd.Value.ToString("HH:mm");
        var updatedWeekendStart = _weekendStart.Value.ToString("HH:mm");
        var updatedWeekendEnd = _weekendEnd.Value.ToString("HH:mm");
        var scheduleChanged = ScheduleChangePolicy.HasChanged(
            current,
            updatedUseWeekendSchedule,
            updatedWeekdayStart,
            updatedWeekdayEnd,
            updatedWeekendStart,
            updatedWeekendEnd);

        if (scheduleChanged)
        {
            ScheduleChangePolicy.AssertCanChange(current, state, now);
        }

        current.Enabled = _enabled.Checked;
        current.Schedule.UseWeekendSchedule = updatedUseWeekendSchedule;
        current.Schedule.Weekdays.Start = updatedWeekdayStart;
        current.Schedule.Weekdays.End = updatedWeekdayEnd;
        current.Schedule.Weekends.Start = updatedWeekendStart;
        current.Schedule.Weekends.End = updatedWeekendEnd;
        current.WarningMinutes = ParseWarnings(_warnings.Text);
        current.EnforcementMode = (_mode.SelectedItem as ModeOption)?.Value ?? "lock_shutdown";
        current.GraceMinutes = (int)_grace.Value;
        current.LockCheckSeconds = (int)_lockSeconds.Value;
        current.LoggingEnabled = _logging.Checked;
        current.MessageTitle = string.IsNullOrWhiteSpace(_titleBox.Text) ? "SleepyNight" : _titleBox.Text.Trim();
        current.EmergencyCode = _emergencyCode.Text ?? string.Empty;

        ConfigStore.Save(_root, current);
        if (scheduleChanged)
        {
            state.LastScheduleChangeAt = now;
            StateStore.Save(_root, state);
            Logger.Append(_root, $"Desktop bedtime schedule changed. Next schedule change is available on {now.AddDays(Math.Max(0, current.ScheduleChangeCooldownDays)):dd.MM.yyyy HH:mm}.");
        }

        Logger.Append(_root, "Desktop settings saved.");
        RefreshDashboard();
    }

    private void RefreshDashboard()
    {
        WatchdogController.RunTick(_root);
        var config = ConfigStore.Load(_root);
        var state = StateStore.Load(_root);
        var status = StatusStore.Load(_root);
        var snapshot = ScheduleLogic.BuildSnapshot(_root, config, state, status, DateTimeOffset.Now);

        _phasePill.Text = snapshot.BadgeText;
        _phasePill.BackColor = snapshot.BadgeColor;
        _phasePill.ForeColor = snapshot.BadgeTextColor;
        _testModePill.Visible = snapshot.TestModeActive;

        _heroTitle.Text = snapshot.BadgeText switch
        {
            "RESTRICTED" => "Night restriction is active",
            "SKIP ACTIVE" => "Skip is active",
            "PROTECTION OFF" => "Protection is off",
            _ => "Bedtime protection"
        };
        _heroSubtitle.Text = snapshot.CountdownValue == "--"
            ? snapshot.HeroSubtitle
            : $"{snapshot.CountdownCaption}: {snapshot.CountdownValue}";
        _heroMeta.Text = string.IsNullOrWhiteSpace(snapshot.WindowMeta)
            ? snapshot.HeroSubtitle
            : $"{snapshot.WindowTitle} - {snapshot.WindowMeta}";

        _countdownValue.Text = snapshot.CountdownValue;
        _countdownCaption.Text = snapshot.CountdownCaption;
        _windowTitle.Text = snapshot.WindowTitle;
        _windowMeta.Text = snapshot.WindowMeta;
        _windowBody.Text = snapshot.WindowBody;

        _agentState.Text = snapshot.AgentText;
        _agentState.ForeColor = snapshot.AgentRunning ? _white : _warning;
        _autostartState.Text = snapshot.AutostartText;
        _autostartState.ForeColor = snapshot.AutostartHealthy ? _cyanSoft : _warning;
        _healthHeartbeatState.Text = snapshot.HeartbeatText;
        _watchdogState.Text = snapshot.WatchdogText;
        _watchdogState.ForeColor = snapshot.WatchdogText.Contains("attention", StringComparison.OrdinalIgnoreCase) ? _warning : _cyanSoft;
        _modeState.Text = snapshot.ModeText;
        _healthActionState.Text = snapshot.LastActionText;
        _testModeState.Text = snapshot.TestModeText;
        _skipState.Text = snapshot.SkipText;
        _scheduleAvailabilityState.Text = snapshot.ScheduleAvailabilityText;
        _tonightSummaryState.Text = snapshot.TonightSummaryText;
        _footerHint.Text = snapshot.FooterHint;

        if (_startAgentButton is not null) _startAgentButton.Enabled = !snapshot.AgentRunning;
        if (_stopAgentButton is not null) _stopAgentButton.Enabled = snapshot.AgentRunning;
        if (_testButton is not null) _testButton.Enabled = !snapshot.TestModeActive;
        if (_stopTestButton is not null)
        {
            _stopTestButton.Enabled = snapshot.TestModeActive;
            _stopTestButton.Visible = snapshot.TestModeActive;
        }
        if (_installAutostartButton is not null) _installAutostartButton.Enabled = !snapshot.AutostartInstalled;
        if (_removeAutostartButton is not null) _removeAutostartButton.Enabled = snapshot.AutostartInstalled;
        if (_repairAutostartButton is not null) _repairAutostartButton.Enabled = true;
        if (_skipTonightButton is not null) _skipTonightButton.Enabled = snapshot.CanSkip;
        if (_clearSkipButton is not null) _clearSkipButton.Enabled = snapshot.SkipActive;
    }

    private void ApplyStateStyling(DashboardSnapshot snapshot)
    {
        if (_heroCard is null || _countdownCard is null || _statusCard is null)
        {
            return;
        }

        var restricted = string.Equals(snapshot.BadgeText, "RESTRICTED", StringComparison.OrdinalIgnoreCase);
        var skipActive = string.Equals(snapshot.BadgeText, "SKIP ACTIVE", StringComparison.OrdinalIgnoreCase);
        var protectionOff = string.Equals(snapshot.BadgeText, "PROTECTION OFF", StringComparison.OrdinalIgnoreCase);
        var needsAttention = !snapshot.AgentRunning || !snapshot.AutostartHealthy || snapshot.WatchdogText.Contains("attention", StringComparison.OrdinalIgnoreCase);

        var heroFill = restricted
            ? Color.FromArgb(214, 66, 30, 54)
            : skipActive
                ? Color.FromArgb(212, 78, 62, 38)
                : protectionOff
                    ? Color.FromArgb(196, 42, 52, 92)
                    : Color.FromArgb(198, _cardAlt.R, _cardAlt.G, _cardAlt.B);
        var heroBorder = restricted
            ? Color.FromArgb(92, 255, 148, 148)
            : skipActive
                ? Color.FromArgb(72, 255, 214, 128)
                : Color.FromArgb(32, _cyan);

        _heroCard.FillColor = heroFill;
        _heroCard.BorderColor = heroBorder;

        _countdownCard.FillColor = restricted
            ? Color.FromArgb(210, 60, 28, 52)
            : Color.FromArgb(198, _card.R, _card.G, _card.B);
        _countdownCard.BorderColor = restricted
            ? Color.FromArgb(78, 255, 148, 148)
            : Color.FromArgb(18, _cyan);

        _statusCard.BorderColor = needsAttention
            ? Color.FromArgb(78, 255, 214, 128)
            : Color.FromArgb(18, _cyan);

        _countdownValue.ForeColor = restricted ? Color.FromArgb(255, 236, 214) : _white;
        _countdownCaption.ForeColor = restricted ? Color.FromArgb(255, 214, 188) : _cyanSoft;

        _heroCard.Invalidate();
        _countdownCard.Invalidate();
        _statusCard.Invalidate();
    }
    private void StartAgent()
    {
        if (AgentController.Start(_root))
        {
            Logger.Append(_root, "Desktop UI started the background agent.");
        }

        RefreshDashboard();
    }

    private void ConfirmAndStopAgent()
    {
        if (!ConfirmAction("Stop the background agent?", "SleepyNight"))
        {
            return;
        }

        StopAgent();
    }

    private void StopAgent()
    {
        var killed = AgentController.Stop(_root);
        Logger.Append(_root, killed > 0
            ? $"Desktop UI stopped {killed} agent process(es)."
            : "Desktop UI stop requested, but no agent process was found.");
        RefreshDashboard();
    }

    private void RunInstaller(bool uninstall)
    {
        var installer = AppPaths.InstallerPath(_root);
        if (!File.Exists(installer))
        {
            throw new FileNotFoundException("Installer script not found.", installer);
        }

        var args = uninstall
            ? $"-NoProfile -ExecutionPolicy Bypass -File \"{installer}\" -Uninstall"
            : $"-NoProfile -ExecutionPolicy Bypass -File \"{installer}\"";

        try
        {
            using var process = Process.Start(new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = args,
                WorkingDirectory = _root,
                UseShellExecute = true,
                Verb = "runas",
                WindowStyle = ProcessWindowStyle.Normal
            });

            if (process is null)
            {
                throw new InvalidOperationException("Could not start the autostart installer.");
            }

            process.WaitForExit();
            if (process.ExitCode != 0)
            {
                throw new InvalidOperationException(
                    $"The autostart installer exited with code {process.ExitCode}. Try running SleepyNight as administrator and try again.");
            }
        }
        catch (Win32Exception ex) when (ex.NativeErrorCode == 1223)
        {
            throw new OperationCanceledException("Autostart installation was canceled at the Windows permission prompt.", ex);
        }

        Logger.Append(_root, uninstall ? "Autostart tasks removed." : "Autostart tasks installed.");
        RefreshDashboard();
    }

    private void ConfirmAndRemoveAutostart()
    {
        if (!ConfirmAction("Remove autostart tasks? The bedtime protection will not come back automatically after sign-in.", "SleepyNight"))
        {
            return;
        }

        RunInstaller(true);
    }

    private void RepairAutostart()
    {
        RunInstaller(false);
        Logger.Append(_root, "Desktop UI repaired autostart tasks.");
        RefreshDashboard();
    }

    private void ConfirmAndClearSkip()
    {
        if (!ConfirmAction("Clear the current skip? Tonight will be protected again.", "SleepyNight"))
        {
            return;
        }

        ClearSkip();
    }

    private void ConfirmAndStopTest()
    {
        if (!ConfirmAction("Stop test mode and restore the saved bedtime schedule?", "SleepyNight"))
        {
            return;
        }

        StopQuickTestWindow();
    }

    private void SkipTonight()
    {
        var config = ConfigStore.Load(_root);
        var state = StateStore.Load(_root);
        var now = DateTimeOffset.Now;
        SkipPolicy.AssertCanActivate(config, state, now);
        var snapshot = ScheduleLogic.BuildSnapshot(_root, config, state, StatusStore.Load(_root), now);
        var until = snapshot.InRestriction ? snapshot.CurrentWindow.End : snapshot.NextWindow.End;

        state.SkipUntil = until;
        state.LastSkipActivatedAt = now;
        StateStore.Save(_root, state);
        Logger.Append(_root, $"Skip is active until {until:dd.MM.yyyy HH:mm}.");
        RefreshDashboard();
    }

    private void ClearSkip()
    {
        var state = StateStore.Load(_root);
        state.SkipUntil = null;
        StateStore.Save(_root, state);
        Logger.Append(_root, "Skip was cleared.");
        RefreshDashboard();
    }

    private void OpenLog()
    {
        var logPath = AppPaths.LogPath(_root);
        if (!File.Exists(logPath))
        {
            File.WriteAllText(logPath, string.Empty);
        }

        var logForm = new Form
        {
            Text = "SleepyNight Log",
            Icon = _appIcon ?? Icon,
            StartPosition = FormStartPosition.CenterParent,
            Size = new Size(900, 620),
            MinimumSize = new Size(760, 480),
            BackColor = _shell,
            ForeColor = _white,
            Font = new Font("Segoe UI", 9.5f)
        };

        var logBox = new TextBox
        {
            Multiline = true,
            ReadOnly = true,
            ScrollBars = ScrollBars.Vertical,
            BorderStyle = BorderStyle.FixedSingle,
            BackColor = Color.FromArgb(245, 248, 255),
            ForeColor = _shell,
            Font = new Font("Consolas", 10f),
            Left = 18,
            Top = 56,
            Width = 848,
            Height = 500,
            Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right
        };

        void LoadLogContent()
        {
            logBox.Text = File.Exists(logPath) ? File.ReadAllText(logPath) : string.Empty;
            logBox.SelectionStart = logBox.TextLength;
            logBox.ScrollToCaret();
        }

        var title = CreateLabel("Recent activity log", 18, 16, 240, 22, _white, 12, FontStyle.Bold);
        var refreshButton = new Button
        {
            Text = "Refresh",
            Left = 682,
            Top = 14,
            Width = 88,
            Height = 30,
            BackColor = _cardAlt,
            ForeColor = _white,
            FlatStyle = FlatStyle.Flat,
            Anchor = AnchorStyles.Top | AnchorStyles.Right,
            Cursor = Cursors.Hand,
            Font = new Font("Segoe UI Semibold", 9.2f)
        };
        refreshButton.FlatAppearance.BorderColor = _line;
        refreshButton.FlatAppearance.BorderSize = 1;
        refreshButton.Click += (_, _) => LoadLogContent();

        var closeButton = new Button
        {
            Text = "Close",
            Left = 778,
            Top = 14,
            Width = 88,
            Height = 30,
            BackColor = _shellSoftAlt,
            ForeColor = _white,
            FlatStyle = FlatStyle.Flat,
            Anchor = AnchorStyles.Top | AnchorStyles.Right,
            Cursor = Cursors.Hand,
            Font = new Font("Segoe UI Semibold", 9.2f)
        };
        closeButton.FlatAppearance.BorderColor = _line;
        closeButton.FlatAppearance.BorderSize = 1;
        closeButton.Click += (_, _) => logForm.Close();

        logForm.Controls.Add(title);
        logForm.Controls.Add(refreshButton);
        logForm.Controls.Add(closeButton);
        logForm.Controls.Add(logBox);
        LoadLogContent();
        logForm.ShowDialog(this);
    }

    private void CreateQuickTestWindow()
    {
        var config = ConfigStore.Load(_root);
        var state = StateStore.Load(_root);
        var now = DateTime.Now;
        var start = now.AddMinutes(2);
        var end = start.AddMinutes(20);
        var startText = start.ToString("HH:mm");
        var endText = end.ToString("HH:mm");

        if (state.QuickTestBackupConfig is null)
        {
            state.QuickTestBackupConfig = CloneConfig(config);
            StateStore.Save(_root, state);
        }

        config.Enabled = true;
        config.Schedule.UseWeekendSchedule = true;
        config.Schedule.Weekdays.Start = startText;
        config.Schedule.Weekdays.End = endText;
        config.Schedule.Weekends.Start = startText;
        config.Schedule.Weekends.End = endText;
        config.WarningMinutes = new[] { 1 };
        config.EnforcementMode = "lock_only";
        config.GraceMinutes = 1;
        config.LockCheckSeconds = 30;

        ConfigStore.Save(_root, config);
        LoadConfigIntoControls();
        Logger.Append(_root, $"Quick test configured for {startText}-{endText}.");
        RefreshDashboard();
    }

    private void StopQuickTestWindow()
    {
        var state = StateStore.Load(_root);
        var config = state.QuickTestBackupConfig is null
            ? AppConfigDefaults.Create()
            : CloneConfig(state.QuickTestBackupConfig);

        ConfigStore.Save(_root, config);
        state.QuickTestBackupConfig = null;
        StateStore.Save(_root, state);
        LoadConfigIntoControls();
        Logger.Append(_root, "Quick test was stopped and the previous bedtime schedule was restored.");
        RefreshDashboard();
    }

    private void HideToTray()
    {
        Hide();
        ShowInTaskbar = false;
        _notifyIcon.Visible = true;
        _notifyIcon.BalloonTipTitle = "SleepyNight";
        _notifyIcon.BalloonTipText = "The dashboard is still running in the tray.";
        _notifyIcon.ShowBalloonTip(1400);
    }

    private void ShowFromTray()
    {
        Show();
        WindowState = FormWindowState.Normal;
        ShowInTaskbar = true;
        Activate();
    }

    private void ExitApp()
    {
        _allowExit = true;
        _notifyIcon.Visible = false;
        Close();
    }

    private bool ConfirmAction(string message, string title)
    {
        return MessageBox.Show(this, message, title, MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes;
    }

    private static DateTime TodayAt(string hhmm)
    {
        if (!TimeSpan.TryParse(hhmm, out var time))
        {
            time = TimeSpan.FromHours(20.5);
        }

        return DateTime.Today.Add(time);
    }

    private static decimal ClampDecimal(int value, decimal min, decimal max)
    {
        var current = (decimal)value;
        if (current < min)
        {
            return min;
        }

        return current > max ? max : current;
    }

    private static int[] ParseWarnings(string text)
    {
        var values = (text ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(part => int.TryParse(part, out var number) ? number : -1)
            .Where(number => number >= 0)
            .Distinct()
            .OrderByDescending(number => number)
            .ToArray();

        return values.Length > 0 ? values : new[] { 60, 30, 15, 10, 5, 1 };
    }

    private static AppConfig CloneConfig(AppConfig config)
        => JsonSerializer.Deserialize<AppConfig>(JsonSerializer.Serialize(config)) ?? AppConfigDefaults.Create();
}

internal static class AppPaths
{
    public static string FindRoot()
    {
        var current = AppContext.BaseDirectory;
        if (LooksLikeRoot(current))
        {
            return current;
        }

        var directory = new DirectoryInfo(current);
        while (directory is not null)
        {
            if (LooksLikeRoot(directory.FullName))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        return AppContext.BaseDirectory;
    }

    public static string ConfigPath(string root) => Path.Combine(root, "sleepy-night-config.json");
    public static string StatePath(string root) => Path.Combine(root, "sleepy-night-state.json");
    public static string StatusPath(string root) => Path.Combine(root, "sleepy-night-status.json");
    public static string LogPath(string root) => Path.Combine(root, "sleepy-night.log");
    public static string AgentScriptPath(string root) => Path.Combine(root, "sleepy-night-agent.ps1");
    public static string InstallerPath(string root) => Path.Combine(root, "install-sleepy-night-tasks.ps1");
    public static string WatchdogScriptPath(string root) => Path.Combine(root, "sleepy-night-watchdog.ps1");
    public static string AppIconPath(string root) => Path.Combine(root, "Images", "IconSleepyNight.ico");

    private static bool LooksLikeRoot(string path)
        => File.Exists(Path.Combine(path, "sleepy-night-config.json"))
           && File.Exists(Path.Combine(path, "sleepy-night-agent.ps1"));
}

internal static class ConfigStore
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
        WriteIndented = true
    };

    public static AppConfig Load(string root)
    {
        var path = AppPaths.ConfigPath(root);
        var config = ReadJson(path, AppConfigDefaults.Create());
        config.Schedule ??= new ScheduleConfig();
        config.Schedule.Weekdays ??= new ScheduleWindowConfig();
        config.Schedule.Weekends ??= new ScheduleWindowConfig();
        config.WarningMinutes ??= new[] { 60, 30, 15, 10, 5, 1 };
        config.MessageTitle ??= "SleepyNight";
        config.EnforcementMode ??= "lock_shutdown";
        config.EmergencyCode ??= string.Empty;
        return config;
    }

    public static void Save(string root, AppConfig config)
    {
        var path = AppPaths.ConfigPath(root);
        File.WriteAllText(path, JsonSerializer.Serialize(config, Options));
    }

    private static T ReadJson<T>(string path, T fallback)
    {
        try
        {
            if (!File.Exists(path))
            {
                return fallback;
            }

            var raw = File.ReadAllText(path);
            return JsonSerializer.Deserialize<T>(raw, Options) ?? fallback;
        }
        catch
        {
            return fallback;
        }
    }
}

internal static class StateStore
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
        WriteIndented = true
    };

    public static AppState Load(string root) => ReadJson(AppPaths.StatePath(root), new AppState());

    public static void Save(string root, AppState state)
    {
        state.LastUpdated = DateTimeOffset.Now;
        File.WriteAllText(AppPaths.StatePath(root), JsonSerializer.Serialize(state, Options));
    }

    private static T ReadJson<T>(string path, T fallback)
    {
        try
        {
            if (!File.Exists(path))
            {
                return fallback;
            }

            var raw = File.ReadAllText(path);
            return JsonSerializer.Deserialize<T>(raw, Options) ?? fallback;
        }
        catch
        {
            return fallback;
        }
    }
}

internal static class StatusStore
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
        WriteIndented = true
    };

    public static AppStatus Load(string root) => ReadJson(AppPaths.StatusPath(root), new AppStatus());

    public static void Save(string root, AppStatus status)
    {
        status.LastUpdated = DateTimeOffset.Now;
        File.WriteAllText(AppPaths.StatusPath(root), JsonSerializer.Serialize(status, Options));
    }

    private static T ReadJson<T>(string path, T fallback)
    {
        try
        {
            if (!File.Exists(path))
            {
                return fallback;
            }

            var raw = File.ReadAllText(path);
            return JsonSerializer.Deserialize<T>(raw, Options) ?? fallback;
        }
        catch
        {
            return fallback;
        }
    }
}

internal static class AgentController
{
    public static bool Start(string root)
    {
        if (IsRunning(root))
        {
            return false;
        }

        var scriptPath = AppPaths.AgentScriptPath(root);
        if (!File.Exists(scriptPath))
        {
            throw new FileNotFoundException("Agent script not found.", scriptPath);
        }

        Process.Start(new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = $"-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\"",
            WorkingDirectory = root,
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden
        });

        return true;
    }

    public static int Stop(string root)
    {
        var status = StatusStore.Load(root);
        var config = ConfigStore.Load(root);
        var ids = new HashSet<int>();
        if (status.AgentPid is int pid && pid > 0)
        {
            ids.Add(pid);
        }

        var killed = 0;
        foreach (var id in ids)
        {
            try
            {
                using var process = Process.GetProcessById(id);
                if (!process.HasExited)
                {
                    process.Kill(true);
                    killed++;
                }
            }
            catch
            {
            }
        }

        return killed;
    }

    public static bool IsRunning(string root)
    {
        var status = StatusStore.Load(root);
        var config = ConfigStore.Load(root);
        if (status.AgentPid is not int pid || pid <= 0)
        {
            return false;
        }

        if (!status.HeartbeatUtc.HasValue)
        {
            return false;
        }

        var heartbeatFreshSeconds = Math.Max(15, config.WatchdogHeartbeatFreshSeconds);
        if (DateTimeOffset.UtcNow - status.HeartbeatUtc.Value > TimeSpan.FromSeconds(heartbeatFreshSeconds))
        {
            return false;
        }

        try
        {
            using var process = Process.GetProcessById(pid);
            return !process.HasExited;
        }
        catch
        {
            return false;
        }
    }
}

internal static class TaskSchedulerHelper
{
    public static AutostartStatus GetAutostartStatus()
    {
        var agentInstalled = IsTaskInstalled("SleepyNight Agent");
        var watchdogInstalled = IsTaskInstalled("SleepyNight Watchdog");
        return new AutostartStatus
        {
            AgentInstalled = agentInstalled,
            WatchdogInstalled = watchdogInstalled
        };
    }

    public static bool IsAutostartInstalled()
        => GetAutostartStatus().Installed;

    private static bool IsTaskInstalled(string taskName)
    {
        try
        {
            using var process = Process.Start(new ProcessStartInfo
            {
                FileName = "schtasks.exe",
                Arguments = $"/Query /TN \"{taskName}\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            });

            process?.WaitForExit(4000);
            return process is not null && process.ExitCode == 0;
        }
        catch
        {
            return false;
        }
    }
}

internal sealed class AutostartStatus
{
    public bool AgentInstalled { get; set; }
    public bool WatchdogInstalled { get; set; }
    public bool Installed => AgentInstalled || WatchdogInstalled;
    public bool Healthy => AgentInstalled && WatchdogInstalled;

    public string SummaryText => (AgentInstalled, WatchdogInstalled) switch
    {
        (true, true) => "Autostart ready: agent + watchdog",
        (true, false) => "Autostart partial: watchdog missing",
        (false, true) => "Autostart partial: agent task missing",
        _ => "Autostart is not installed"
    };
}
internal static class WatchdogController
{
    private static readonly TimeSpan DesktopTickInterval = TimeSpan.FromSeconds(30);

    public static void RunTick(string root)
    {
        try
        {
            var config = ConfigStore.Load(root);
            var state = StateStore.Load(root);
            var status = StatusStore.Load(root);
            var now = DateTimeOffset.Now;

            if (!config.WatchdogEnabled)
            {
                Persist(root, state, status, now, "disabled", "Watchdog is disabled", null);
                return;
            }

            if (state.LastWatchdogCheckAt.HasValue && now - state.LastWatchdogCheckAt.Value < DesktopTickInterval)
            {
                return;
            }

            if (!config.Enabled)
            {
                Persist(root, state, status, now, "idle", "Protection is disabled", null);
                return;
            }

            var health = Evaluate(root, config, status, now);
            if (!health.ShouldRestart)
            {
                Persist(root, state, status, now, "healthy", "Agent is healthy", null);
                return;
            }

            var cooldown = TimeSpan.FromSeconds(Math.Max(5, config.WatchdogRepairCooldownSeconds));
            if (state.LastWatchdogRepairAt.HasValue && now - state.LastWatchdogRepairAt.Value < cooldown)
            {
                var remaining = cooldown - (now - state.LastWatchdogRepairAt.Value);
                Persist(root, state, status, now, "cooldown", $"Repair cooldown is active for {Math.Max(1, (int)Math.Ceiling(remaining.TotalSeconds))} sec.", null);
                return;
            }

            if (health.ProcessAlive && !health.HeartbeatHealthy)
            {
                var stopped = AgentController.Stop(root);
                if (stopped > 0)
                {
                    Logger.Append(root, $"Watchdog stopped {stopped} stale agent process(es) before restart.");
                    System.Threading.Thread.Sleep(1500);
                }
            }

            var started = AgentController.Start(root);
            if (started)
            {
                var message = $"Watchdog restarted the background agent because {health.Reason.ToLowerInvariant()}.";
                Logger.Append(root, message);
                Persist(root, state, status, now, "restarted", message, now);
                return;
            }

            health = Evaluate(root, config, StatusStore.Load(root), now);
            if (!health.ShouldRestart)
            {
                Persist(root, state, status, now, "healthy", "Agent is healthy", null);
                return;
            }

            var failedReason = $"Watchdog detected an unhealthy agent but could not restart it: {health.Reason}.";
            Logger.Append(root, failedReason);
            Persist(root, state, status, now, "warning", failedReason, null);
        }
        catch (Exception ex)
        {
            Logger.Append(root, $"Watchdog error: {ex.Message}");
        }
    }

    private static AgentHealth Evaluate(string root, AppConfig config, AppStatus status, DateTimeOffset now)
    {
        var processAlive = IsProcessAlive(status.AgentPid);
        var heartbeatFreshSeconds = Math.Max(15, config.WatchdogHeartbeatFreshSeconds);
        var heartbeatAge = status.HeartbeatUtc.HasValue ? now.ToUniversalTime() - status.HeartbeatUtc.Value.ToUniversalTime() : (TimeSpan?)null;
        var heartbeatHealthy = heartbeatAge.HasValue && heartbeatAge.Value <= TimeSpan.FromSeconds(heartbeatFreshSeconds);

        var reason = !processAlive
            ? "agent process is not running"
            : !heartbeatHealthy
                ? heartbeatAge.HasValue
                    ? "heartbeat is stale"
                    : "heartbeat is missing"
                : "agent is healthy";

        return new AgentHealth
        {
            ProcessAlive = processAlive,
            HeartbeatHealthy = heartbeatHealthy,
            ShouldRestart = !processAlive || !heartbeatHealthy,
            Reason = reason
        };
    }

    private static bool IsProcessAlive(int? pid)
    {
        if (!pid.HasValue || pid.Value <= 0)
        {
            return false;
        }

        try
        {
            using var process = Process.GetProcessById(pid.Value);
            return !process.HasExited;
        }
        catch
        {
            return false;
        }
    }


    private static void Persist(string root, AppState state, AppStatus status, DateTimeOffset now, string watchdogState, string reason, DateTimeOffset? repairAt)
    {
        state.LastWatchdogCheckAt = now;
        state.LastWatchdogReason = reason;
        if (repairAt.HasValue)
        {
            state.LastWatchdogRepairAt = repairAt;
        }
        StateStore.Save(root, state);

        status.WatchdogState = watchdogState;
        status.WatchdogReason = reason;
        status.WatchdogLastCheckUtc = now.ToUniversalTime();
        if (repairAt.HasValue)
        {
            status.WatchdogLastRepairUtc = repairAt.Value.ToUniversalTime();
        }
        StatusStore.Save(root, status);
    }

    private sealed class AgentHealth
    {
        public bool ProcessAlive { get; set; }
        public bool HeartbeatHealthy { get; set; }
        public bool ShouldRestart { get; set; }
        public string Reason { get; set; } = string.Empty;
    }
}
internal static class SkipPolicy
{
    public static DateTimeOffset? GetNextAvailableAt(AppConfig config, AppState state)
    {
        if (!state.LastSkipActivatedAt.HasValue) {
            return null;
        }

        var cooldownDays = config.SkipCooldownDays;
        if (cooldownDays <= 0) {
            return null;
        }

        return state.LastSkipActivatedAt.Value.AddDays(cooldownDays);
    }

    public static void AssertCanActivate(AppConfig config, AppState state, DateTimeOffset now)
    {
        if (state.SkipUntil.HasValue && state.SkipUntil.Value > now) {
            throw new InvalidOperationException($"Skip is already active until {state.SkipUntil.Value:dd.MM.yyyy HH:mm}.");
        }

        var nextAvailableAt = GetNextAvailableAt(config, state);
        if (nextAvailableAt.HasValue && nextAvailableAt.Value > now) {
            throw new InvalidOperationException($"Skip is on cooldown until {nextAvailableAt.Value:dd.MM.yyyy HH:mm}.");
        }
    }
}


internal static class ScheduleChangePolicy
{
    public static bool HasChanged(
        AppConfig current,
        bool useWeekendSchedule,
        string weekdayStart,
        string weekdayEnd,
        string weekendStart,
        string weekendEnd)
    {
        return current.Schedule.UseWeekendSchedule != useWeekendSchedule
            || !string.Equals(current.Schedule.Weekdays.Start, weekdayStart, StringComparison.Ordinal)
            || !string.Equals(current.Schedule.Weekdays.End, weekdayEnd, StringComparison.Ordinal)
            || !string.Equals(current.Schedule.Weekends.Start, weekendStart, StringComparison.Ordinal)
            || !string.Equals(current.Schedule.Weekends.End, weekendEnd, StringComparison.Ordinal);
    }

    public static DateTimeOffset? GetNextAvailableAt(AppConfig config, AppState state)
    {
        if (!state.LastScheduleChangeAt.HasValue)
        {
            return null;
        }

        var cooldownDays = config.ScheduleChangeCooldownDays;
        if (cooldownDays <= 0)
        {
            return null;
        }

        return state.LastScheduleChangeAt.Value.AddDays(cooldownDays);
    }

    public static void AssertCanChange(AppConfig config, AppState state, DateTimeOffset now)
    {
        var nextAvailableAt = GetNextAvailableAt(config, state);
        if (nextAvailableAt.HasValue && nextAvailableAt.Value > now)
        {
            throw new InvalidOperationException($"Schedule change is on cooldown until {nextAvailableAt.Value:dd.MM.yyyy HH:mm}.");
        }
    }
}
internal static class ScheduleLogic
{
    public static DashboardSnapshot BuildSnapshot(string root, AppConfig config, AppState state, AppStatus status, DateTimeOffset now)
    {
        var currentWindow = GetRelevantWindow(config, now);
        var skipActive = state.SkipUntil.HasValue && state.SkipUntil.Value > now;
        var nextSkipAvailableAt = SkipPolicy.GetNextAvailableAt(config, state);
        var nextScheduleChangeAvailableAt = ScheduleChangePolicy.GetNextAvailableAt(config, state);
        var autostart = TaskSchedulerHelper.GetAutostartStatus();
        var autostartInstalled = autostart.Installed;
        var agentRunning = AgentController.IsRunning(root) || status.AgentRunning;
        var testModeActive = state.QuickTestBackupConfig is not null;
        var canSkip = !skipActive && (!nextSkipAvailableAt.HasValue || nextSkipAvailableAt.Value <= now);

        var snapshot = new DashboardSnapshot
        {
            CurrentWindow = currentWindow,
            NextWindow = currentWindow.InRestriction ? GetRelevantWindow(config, currentWindow.End.AddMinutes(1)) : currentWindow,
            InRestriction = currentWindow.InRestriction && !skipActive,
            TestModeActive = testModeActive,
            AgentRunning = agentRunning,
            AutostartInstalled = autostartInstalled,
            AutostartHealthy = autostart.Healthy,
            RepairAutostartRecommended = !autostart.Healthy,
            SkipActive = skipActive,
            CanSkip = canSkip
        };

        if (skipActive)
        {
            snapshot.BadgeText = "SKIP ACTIVE";
            snapshot.BadgeColor = Color.FromArgb(234, 195, 94);
            snapshot.BadgeTextColor = Color.FromArgb(19, 30, 66);
            snapshot.HeroSubtitle = $"Skip is active until {state.SkipUntil!.Value:dd.MM HH:mm}. The restriction window is temporarily standing down.";
            snapshot.CountdownValue = FormatCountdown(state.SkipUntil.Value - now);
            snapshot.CountdownCaption = "Until skip expires";
        }
        else if (snapshot.InRestriction)
        {
            snapshot.BadgeText = "RESTRICTED";
            snapshot.BadgeColor = Color.FromArgb(186, 74, 92);
            snapshot.BadgeTextColor = Color.White;
            snapshot.HeroSubtitle = testModeActive
                ? "Quick test is active and the restricted window is enforcing now. Stop test when you want to restore the saved bedtime schedule."
                : "The restricted window is active. The app is supposed to keep the machine unavailable until the night window ends.";
            snapshot.CountdownValue = FormatCountdown(currentWindow.End - now);
            snapshot.CountdownCaption = "Until restriction ends";
        }
        else
        {
            snapshot.BadgeText = config.Enabled ? "ALLOWED NOW" : "PROTECTION OFF";
            snapshot.BadgeColor = config.Enabled ? Color.FromArgb(80, 187, 142) : Color.FromArgb(89, 109, 164);
            snapshot.BadgeTextColor = Color.White;
            snapshot.HeroSubtitle = testModeActive
                ? "Quick test is active. The real bedtime schedule is backed up and will return when you stop the test."
                : config.Enabled
                    ? "The system is calm for now. The next restriction window is queued and waiting."
                    : "Protection is disabled. The bedtime rule will not enforce until protection is turned back on.";

            if (config.Enabled)
            {
                var upcoming = currentWindow.InRestriction ? GetRelevantWindow(config, currentWindow.End.AddMinutes(1)) : currentWindow;
                snapshot.CountdownValue = FormatCountdown(upcoming.Start - now);
                snapshot.CountdownCaption = "Until next restriction";
                snapshot.NextWindow = upcoming;
            }
            else
            {
                snapshot.CountdownValue = "--";
                snapshot.CountdownCaption = "Protection disabled";
            }
        }

        var displayWindow = snapshot.InRestriction ? currentWindow : snapshot.NextWindow;
        snapshot.WindowTitle = displayWindow.ScheduleName + " window";
        snapshot.WindowMeta = $"{displayWindow.Start:dd.MM HH:mm} -> {displayWindow.End:dd.MM HH:mm}";
        snapshot.WindowBody = snapshot.InRestriction
            ? "The active window is enforcing now."
            : "This is the next scheduled restriction window.";

        snapshot.AgentText = agentRunning ? "Agent is running" : "Agent is not running";
        snapshot.AutostartText = autostart.SummaryText;
        snapshot.HeartbeatText = FormatHeartbeatText(now, status.HeartbeatUtc);
        snapshot.WatchdogText = FormatWatchdogText(now, config, state, status);
        snapshot.SkipText = skipActive
            ? $"Skip until {state.SkipUntil:dd.MM HH:mm}"
            : nextSkipAvailableAt.HasValue && nextSkipAvailableAt.Value > now
                ? $"Next skip available on {nextSkipAvailableAt.Value:dd.MM HH:mm}"
                : "Skip is ready now";
        snapshot.ScheduleAvailabilityText = nextScheduleChangeAvailableAt.HasValue && nextScheduleChangeAvailableAt.Value > now
            ? $"Schedule change on {nextScheduleChangeAvailableAt.Value:dd.MM HH:mm}"
            : "Schedule change is ready now";
        snapshot.TestModeText = testModeActive
            ? "Test mode active. Real schedule is backed up."
            : "Main bedtime schedule active";
        snapshot.ModeText = "Mode: " + HumanizeMode(config.EnforcementMode);
        snapshot.LastActionText = string.IsNullOrWhiteSpace(status.LastAction) ? (status.StatusText ?? "Waiting for the next window") : status.LastAction;
        snapshot.TonightSummaryText = BuildTonightSummary(config, snapshot.InRestriction ? currentWindow : snapshot.NextWindow);
        snapshot.FooterHint = !autostart.Healthy ? "Autostart is incomplete. Repair it so bedtime protection comes back after sign-in." : !agentRunning && config.Enabled && !skipActive ? "Agent is not running. Start it now or let the watchdog recover it." : status.WatchdogState == "warning" ? status.WatchdogReason : status.StatusText ?? string.Empty;

        return snapshot;
    }

    private static RestrictionWindow GetRelevantWindow(AppConfig config, DateTimeOffset now)
    {
        var previous = GetWindowForDate(config, now.Date.AddDays(-1));
        var today = GetWindowForDate(config, now.Date);
        var tomorrow = GetWindowForDate(config, now.Date.AddDays(1));

        if (now >= previous.Start && now < previous.End)
        {
            previous.InRestriction = true;
            return previous;
        }

        if (now >= today.Start && now < today.End)
        {
            today.InRestriction = true;
            return today;
        }

        if (now < today.Start)
        {
            today.InRestriction = false;
            return today;
        }

        tomorrow.InRestriction = false;
        return tomorrow;
    }

    private static RestrictionWindow GetWindowForDate(AppConfig config, DateTime date)
    {
        var weekend = date.DayOfWeek is DayOfWeek.Saturday or DayOfWeek.Sunday;
        var useWeekend = config.Schedule.UseWeekendSchedule && weekend;
        var rule = useWeekend ? config.Schedule.Weekends : config.Schedule.Weekdays;
        var scheduleName = useWeekend ? "Weekend" : "Weekday";

        var start = ParseWindow(date, rule.Start);
        var end = ParseWindow(date, rule.End);
        if (end <= start)
        {
            end = end.AddDays(1);
        }

        return new RestrictionWindow
        {
            Start = new DateTimeOffset(start),
            End = new DateTimeOffset(end),
            ScheduleName = scheduleName
        };
    }

    private static DateTime ParseWindow(DateTime day, string hhmm)
    {
        if (!TimeSpan.TryParse(hhmm, out var value))
        {
            value = TimeSpan.FromHours(20.5);
        }

        return day.Date.Add(value);
    }

    private static string BuildTonightSummary(AppConfig config, RestrictionWindow window)
    {
        var start = window.Start.ToLocalTime();
        var end = window.End.ToLocalTime();
        var warningMinutes = config.WarningMinutes ?? Array.Empty<int>();
        var warningTimes = warningMinutes.Length == 0
            ? "none"
            : string.Join(", ", warningMinutes.OrderByDescending(minutes => minutes).Select(minutes => start.AddMinutes(-minutes).ToString("HH:mm")));
        var forcedActionAt = start.AddMinutes(Math.Max(0, config.GraceMinutes));

        var actionText = config.EnforcementMode switch
        {
            "warn_only" => $"Action: warnings only before {start:HH:mm}",
            "lock_only" => $"Action: lock at {start:HH:mm}",
            "lock_logoff" => $"Action: lock at {start:HH:mm}, sign out at {forcedActionAt:HH:mm}",
            _ => $"Action: lock at {start:HH:mm}, shut down at {forcedActionAt:HH:mm}"
        };

        return $"Window: {window.ScheduleName} {start:dd.MM HH:mm} -> {end:dd.MM HH:mm}\nWarnings: {warningTimes}\n{actionText}";
    }

    private static string FormatCountdown(TimeSpan span)
    {
        if (span < TimeSpan.Zero)
        {
            span = TimeSpan.Zero;
        }

        var totalHours = (int)span.TotalHours;
        return $"{totalHours:00}:{span.Minutes:00}:{span.Seconds:00}";
    }

    private static string FormatWatchdogText(DateTimeOffset now, AppConfig config, AppState state, AppStatus status)
    {
        if (!config.WatchdogEnabled)
        {
            return "Watchdog: disabled";
        }

        var label = status.WatchdogState switch
        {
            "healthy" => "Watchdog: guarding",
            "restarted" => "Watchdog: repaired agent",
            "cooldown" => "Watchdog: cooldown active",
            "idle" => "Watchdog: idle",
            "disabled" => "Watchdog: disabled",
            "warning" => "Watchdog: attention needed",
            _ => "Watchdog: checking"
        };

        var stamp = status.WatchdogLastRepairUtc ?? state.LastWatchdogRepairAt ?? status.WatchdogLastCheckUtc ?? state.LastWatchdogCheckAt;
        if (!stamp.HasValue)
        {
            return label;
        }

        return $"{label}, {FormatRelativeAge(now - stamp.Value)}";
    }
    private static string FormatHeartbeatText(DateTimeOffset now, DateTimeOffset? heartbeatUtc)
    {
        if (!heartbeatUtc.HasValue)
        {
            return "Heartbeat: unavailable";
        }

        var age = now.ToUniversalTime() - heartbeatUtc.Value.ToUniversalTime();
        var relative = FormatRelativeAge(age);

        if (age <= TimeSpan.FromMinutes(2))
        {
            return $"Heartbeat: healthy, {relative}";
        }

        if (age <= TimeSpan.FromMinutes(10))
        {
            return $"Heartbeat: stale, {relative}";
        }

        return $"Heartbeat: old, {relative}";
    }

    private static string FormatRelativeAge(TimeSpan age)
    {
        if (age < TimeSpan.Zero)
        {
            age = TimeSpan.Zero;
        }

        if (age.TotalSeconds < 60)
        {
            return $"{Math.Max(0, (int)age.TotalSeconds)} sec ago";
        }

        if (age.TotalMinutes < 60)
        {
            return $"{Math.Max(1, (int)age.TotalMinutes)} min ago";
        }

        return $"{Math.Max(1, (int)age.TotalHours)} h ago";
    }

    private static string HumanizeMode(string? mode) => mode switch
    {
        "warn_only" => "Warn only",
        "lock_only" => "Lock only",
        "lock_logoff" => "Lock and sign out",
        _ => "Lock and shut down"
    };
}

internal static class Logger
{
    public static void Append(string root, string message)
    {
        try
        {
            var config = ConfigStore.Load(root);
            if (!config.LoggingEnabled)
            {
                return;
            }

            var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} [INFO] {message}{Environment.NewLine}";
            File.AppendAllText(AppPaths.LogPath(root), line);
        }
        catch
        {
        }
    }
}

internal static class AppConfigDefaults
{
    public static AppConfig Create() => new()
    {
        Enabled = true,
        EnforcementMode = "lock_shutdown",
        EmergencyCode = string.Empty,
        MessageTitle = "SleepyNight",
        WarningMinutes = new[] { 60, 30, 15, 10, 5, 1 },
        Schedule = new ScheduleConfig
        {
            UseWeekendSchedule = true,
            Weekdays = new ScheduleWindowConfig { Start = "20:30", End = "03:00" },
            Weekends = new ScheduleWindowConfig { Start = "22:30", End = "04:00" }
        },
        StatusRefreshSeconds = 5,
        LockCheckSeconds = 30,
        LoggingEnabled = true,
        GraceMinutes = 2,
        SkipCooldownDays = 14,
        ScheduleChangeCooldownDays = 7,
        WatchdogEnabled = true,
        WatchdogHeartbeatFreshSeconds = 120,
        WatchdogRepairCooldownSeconds = 90
    };
}

internal sealed class DashboardSnapshot
{
    public string BadgeText { get; set; } = "ALLOWED NOW";
    public Color BadgeColor { get; set; } = Color.SeaGreen;
    public Color BadgeTextColor { get; set; } = Color.White;
    public string HeroSubtitle { get; set; } = string.Empty;
    public string CountdownValue { get; set; } = "--";
    public string CountdownCaption { get; set; } = string.Empty;
    public string WindowTitle { get; set; } = string.Empty;
    public string WindowMeta { get; set; } = string.Empty;
    public string WindowBody { get; set; } = string.Empty;
    public string AgentText { get; set; } = string.Empty;
    public string AutostartText { get; set; } = string.Empty;
    public string SkipText { get; set; } = string.Empty;
    public string ModeText { get; set; } = string.Empty;
    public string FooterHint { get; set; } = string.Empty;
    public bool TestModeActive { get; set; }
    public bool AgentRunning { get; set; }
    public bool AutostartInstalled { get; set; }
    public bool SkipActive { get; set; }
    public bool AutostartHealthy { get; set; }
    public bool RepairAutostartRecommended { get; set; }
    public bool CanSkip { get; set; }
    public string TestModeText { get; set; } = string.Empty;
    public string ScheduleAvailabilityText { get; set; } = string.Empty;
    public string HeartbeatText { get; set; } = string.Empty;
    public string LastActionText { get; set; } = string.Empty;
    public string WatchdogText { get; set; } = string.Empty;
    public string TonightSummaryText { get; set; } = string.Empty;
    public bool InRestriction { get; set; }
    public RestrictionWindow CurrentWindow { get; set; } = new();
    public RestrictionWindow NextWindow { get; set; } = new();
}

internal sealed class RestrictionWindow
{
    public DateTimeOffset Start { get; set; }
    public DateTimeOffset End { get; set; }
    public string ScheduleName { get; set; } = string.Empty;
    public bool InRestriction { get; set; }
}

internal sealed class ModeOption
{
    public ModeOption(string name, string value)
    {
        Name = name;
        Value = value;
    }

    public string Name { get; }
    public string Value { get; }
    public override string ToString() => Name;
}

internal sealed class AppConfig
{
    public bool Enabled { get; set; }
    public string EnforcementMode { get; set; } = "lock_shutdown";
    public string EmergencyCode { get; set; } = string.Empty;
    public string MessageTitle { get; set; } = "SleepyNight";
    public int[] WarningMinutes { get; set; } = Array.Empty<int>();
    public ScheduleConfig Schedule { get; set; } = new();
    public int StatusRefreshSeconds { get; set; }
    public int LockCheckSeconds { get; set; }
    public int SkipCooldownDays { get; set; } = 14;
    public int ScheduleChangeCooldownDays { get; set; } = 7;
    public bool WatchdogEnabled { get; set; } = true;
    public int WatchdogHeartbeatFreshSeconds { get; set; } = 120;
    public int WatchdogRepairCooldownSeconds { get; set; } = 90;
    public bool LoggingEnabled { get; set; }
    public int GraceMinutes { get; set; }
}

internal sealed class ScheduleConfig
{
    public ScheduleWindowConfig Weekdays { get; set; } = new();
    public ScheduleWindowConfig Weekends { get; set; } = new();
    public bool UseWeekendSchedule { get; set; }
}

internal sealed class ScheduleWindowConfig
{
    public string Start { get; set; } = "20:30";
    public string End { get; set; } = "03:00";
}

internal sealed class AppState
{
    public DateTimeOffset? LastSkipActivatedAt { get; set; }
    public DateTimeOffset? LastScheduleChangeAt { get; set; }
    public AppConfig? QuickTestBackupConfig { get; set; }
    public DateTimeOffset? LastUpdated { get; set; }
    public DateTimeOffset? SkipUntil { get; set; }
    public DateTimeOffset? LastWatchdogCheckAt { get; set; }
    public DateTimeOffset? LastWatchdogRepairAt { get; set; }
    public string LastWatchdogReason { get; set; } = string.Empty;
    public string Note { get; set; } = string.Empty;
}

internal sealed class AppStatus
{
    public DateTimeOffset? NextStart { get; set; }
    public DateTimeOffset? NextEnd { get; set; }
    public bool AgentRunning { get; set; }
    public int? AgentPid { get; set; }
    public DateTimeOffset? LastUpdated { get; set; }
    public DateTimeOffset? SkipUntil { get; set; }
    public string Phase { get; set; } = "unknown";
    public string StatusText { get; set; } = "Status is not available yet";
    public string LastAction { get; set; } = string.Empty;
    public DateTimeOffset? HeartbeatUtc { get; set; }
    public string WatchdogState { get; set; } = "unknown";
    public string WatchdogReason { get; set; } = string.Empty;
    public DateTimeOffset? WatchdogLastCheckUtc { get; set; }
    public DateTimeOffset? WatchdogLastRepairUtc { get; set; }
    public string ActiveSchedule { get; set; } = string.Empty;
}

































