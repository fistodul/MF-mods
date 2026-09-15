class screenRulesKOH extends ScreenRulesTeamDM;

var RageMenuInteger PointsToSpawn;
var localized string TXT_PointsToSpawn;

var RageMenuSubMenu CentralizedSpawn;
var localized string TXT_CentralizedSpawn;

function RageMenuInteger AddIntOption(float YPos, string OptionText, int MinVal, int MaxVal, optional int IncVal)
{
    local RageMenuInteger Item;
    Item = RageMenuInteger(Menu.AddMenuItem(class'RageMenuInteger', FESize(HMargin), FESize(YPos), WinWidth - FESize(2 * HMargin), FESize(48)));

    Item.Text = OptionText;
    Item.ArrowPosRatio = 0.6;
    Item.SetStandardArrowPos(8);
    Item.MinValue = MinVal;
    Item.MaxValue = MaxVal;

    if (IncVal > 0)
        Item.IncValue = IncVal;

    return Item;
}

function RageMenuSubMenu AddYesNoOption(float YPos, string OptionText)
{
    local RageMenuSubMenu Sub;
    local RageMenuMenuItem btn;

    Sub = RageMenuSubMenu(Menu.AddMenuItem(class'RageMenuSubMenu', FESize(HMargin), FESize(YPos), WinWidth - FESize(2 * HMargin), FESize(48)));
    Sub.ArrowPosRatio = 0.6;
    Sub.bOnlyShowSelected = true;

    btn = Sub.AddMenuItem(class'RageButton', Sub.WinWidth / 2 + FESize(Sub.HMargin), 0, Sub.WinWidth / 2 - 2 * FESize(Sub.HMargin), FESize(48), 0);
    btn.Text = TXT_No;

    btn = Sub.AddMenuItem(class'RageButton', Sub.WinWidth / 2 + FESize(Sub.HMargin), 0, Sub.WinWidth / 2 - 2 * FESize(Sub.HMargin), FESize(48), 1);
    btn.Text = TXT_Yes;

    Sub.SetStandardArrowPos(8);
    Sub.Text = OptionText;

    return Sub;
}

function Created()
{
    local RageMenuSubMenu mnubtn;
    Super(RageMenuScreen).Created();

    HMargin = 102;
    YFirst -= 1.5 * YSpacing;

    if (CurrentGameMode() == GameMode_MP_Host)
        YFirst -= 3.5 * YSpacing;

    RageRoot = RageMenuRootWindow(Root);
    Menu = RageMenuMenu(CreateWindow(Class'RageMenuMenu', 0, 0, WinWidth, WinHeight));

    // Game rules controls
    scoreLimit       = AddIntOption(YFirst, TXT_ScoreLimit, 100, ScoreLimitMax, FragLimitIncrement);
    TimeLimit        = AddIntOption(YFirst + YSpacing, TXT_TimeLimit, 0, TimeLimitMax);
    PointsToSpawn    = AddIntOption(YFirst + YSpacing * 2, TXT_PointsToSpawn, 1, 6, 1);
    CentralizedSpawn = AddYesNoOption(YFirst + YSpacing * 3, TXT_CentralizedSpawn);
    FriendlyFire     = AddIntOption(YFirst + YSpacing * 4, TXT_FriendlyFire, 0, FriendlyFireMax, 10);
    RespawnWait      = AddIntOption(YFirst + YSpacing * 5, TXT_RespawnWait, 0, RespawnWaitMax);
    RespawnWait.IntValue = GameTypeClass.Default.RespawnWait;

    HardcoreMode     = AddYesNoOption(YFirst + YSpacing * 6, TXT_HardcoreMode);
    if (GameTypeClass.Default.bHardCoreMode)
        HardcoreMode.SelectByValue(1);

    if (CurrentGameMode() == GameMode_MP_Host)
        AddServerSettings(YFirst + YSpacing * 6 + 12);

    // Bottom Navigation Buttons (OK / Cancel)
    mnubtn = RageMenuSubMenu(Menu.AddMenuItem(class'RageMenuSubMenu', 0, WinHeight - FESize(80), WinWidth, FESize(68)));
    mnubtn.bOnlyShowSelected = false;

    OKButton = RageButton(mnubtn.AddMenuItem(class'RageButtonPageChange', WinWidth / 2 - FESize(244), 0, FESize(236), FESize(68)));
    OKButton.Text = TXT_OK;
    OKButton.Font = F_Large;

    BackButton = RageButton(mnubtn.AddMenuItem(class'RageButtonPageChange', WinWidth / 2 + 4, 0, FESize(236), FESize(68)));
    BackButton.Text = TXT_Cancel;
    BackButton.Font = F_Large;
    BackButton.DownSound = BackSound;

    if (CurrentGameMode() == GameMode_MP_Host)
    {
        RageButtonPageChange(OKButton).DestScreen = class'ScreenStartServer';
        RageButtonPageChange(BackButton).DestScreen = class'ScreenStartServer';
    }
    else
    {
        RageButtonPageChange(OKButton).DestScreen = class'ScreenPractice';
        RageButtonPageChange(BackButton).DestScreen = class'ScreenPractice';
    }

    LoadRules();

    Menu.Selected.ItemWindow.ActivateWindow(0, False);
    Menu.FocusWindow();
    Menu.KeyFocusEnter();
}

function LoadRules()
{
    Super.LoadRules();

    scoreLimit.IntValue = Max(class<KOHGame>(GameTypeClass).Default.GoalTeamScore, 100);
    PointsToSpawn.IntValue = class<KOHGame>(GameTypeClass).Default.PointsToSpawn;

    if (class<KOHGame>(GameTypeClass).Default.bCentralizedSpawning)
        CentralizedSpawn.SelectByValue(1);
    else
        CentralizedSpawn.SelectByValue(0);
}

function SaveRules()
{
    Super.SaveRules();

    class<KOHGame>(GameTypeClass).Default.GoalTeamScore = scoreLimit.IntValue;
    class<KOHGame>(GameTypeClass).Default.PointsToSpawn = PointsToSpawn.IntValue;
    class<KOHGame>(GameTypeClass).Default.bCentralizedSpawning = (CentralizedSpawn.Selected.ItemWindow.IntValue == 1);
    class<KOHGame>(GameTypeClass).static.StaticSaveConfig();
}

defaultproperties
{
     ScoreLimitMax=1000
     TXT_PointsToSpawn="Capture Points (1-6)"
     TXT_CentralizedSpawn="Centralized Spawning"
     TXT_ScoreLimit="Score Limit"
     GameTypeClass=Class'KOH.KOHGame'
     FragLimitIncrement=25
     TXT_Title="King of the Hill Rules"
}
