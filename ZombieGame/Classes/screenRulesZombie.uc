class screenRulesZombie extends ScreenRulesTeamDM;

var RageMenuSubMenu SpawnAnywhere;
var localized string TXT_SpawnAnywhere;

var RageMenuSubMenu KillTransform;
var localized string TXT_KillTransform;

var RageMenuSubMenu ZombieInfect;
var localized string TXT_ZombieInfect;

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
    YFirst -= 2.0 * YSpacing;

    if (CurrentGameMode() == GameMode_MP_Host)
        YFirst -= 4.0 * YSpacing;

    RageRoot = RageMenuRootWindow(Root);
    Menu = RageMenuMenu(CreateWindow(Class'RageMenuMenu', 0, 0, WinWidth, WinHeight));

    // Game rules controls
    scoreLimit       = AddIntOption(YFirst, TXT_ScoreLimit, 1, ScoreLimitMax, FragLimitIncrement);
    TimeLimit        = AddIntOption(YFirst + YSpacing, TXT_TimeLimit, 0, TimeLimitMax);
    SpawnAnywhere    = AddYesNoOption(YFirst + YSpacing * 2, TXT_SpawnAnywhere);
    KillTransform    = AddYesNoOption(YFirst + YSpacing * 3, TXT_KillTransform);
    ZombieInfect     = AddYesNoOption(YFirst + YSpacing * 4, TXT_ZombieInfect);
    FriendlyFire     = AddIntOption(YFirst + YSpacing * 5, TXT_FriendlyFire, 0, FriendlyFireMax, 10);
    RespawnWait      = AddIntOption(YFirst + YSpacing * 6, TXT_RespawnWait, 0, RespawnWaitMax);
    RespawnWait.IntValue = GameTypeClass.Default.RespawnWait;

    HardcoreMode     = AddYesNoOption(YFirst + YSpacing * 7, TXT_HardcoreMode);
    if (GameTypeClass.Default.bHardCoreMode)
        HardcoreMode.SelectByValue(1);

    if (CurrentGameMode() == GameMode_MP_Host)
        AddServerSettings(YFirst + YSpacing * 7 + 12);

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

    if (class<ZombieGame>(GameTypeClass).Default.bSpawnAnywhere)
        SpawnAnywhere.SelectByValue(1);
    else
        SpawnAnywhere.SelectByValue(0);

    if (class<ZombieGame>(GameTypeClass).Default.bKillTransform)
        KillTransform.SelectByValue(1);
    else
        KillTransform.SelectByValue(0);

    if (class<ZombieGame>(GameTypeClass).Default.bZombieInfect)
        ZombieInfect.SelectByValue(1);
    else
        ZombieInfect.SelectByValue(0);
}

function SaveRules()
{
    Super.SaveRules();

    class<ZombieGame>(GameTypeClass).Default.bSpawnAnywhere = (SpawnAnywhere.Selected.ItemWindow.IntValue == 1);
    class<ZombieGame>(GameTypeClass).Default.bKillTransform = (KillTransform.Selected.ItemWindow.IntValue == 1);
    class<ZombieGame>(GameTypeClass).Default.bZombieInfect = (ZombieInfect.Selected.ItemWindow.IntValue == 1);
    class<ZombieGame>(GameTypeClass).static.StaticSaveConfig();
}

defaultproperties
{
     ScoreLimitMax=100
     TXT_SpawnAnywhere="Spawn Anywhere"
     TXT_KillTransform="Transform on Death"
     TXT_ZombieInfect="Zombie Infection"
     GameTypeClass=Class'ZombieGame.ZombieGame'
     FragLimitIncrement=1
     TXT_Title="Zombie Rules"
}
