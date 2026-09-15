//=============================================================================
// KOHGame by Animeman - King of the Hill Multi-Point Domination Gametype
//=============================================================================
class KOHGame extends RageTeamGame;

var config int PointsToSpawn;          // Number of capture points (1 to 6)
var config bool bCentralizedSpawning;  // True = balanced center & locks, False = distributed neutral spots
var config float MinDistance;          // Base distance used for proximity checks

// Candidate pool for capture point placement
var vector PoolLoc[128];
var rotator PoolRot[128];
var byte PoolType[128]; // 0 = central, 1 = bases, 2 = random points
var int PoolCount;

// Base locations for distance calculation
var vector BlueBaseLoc, RedBaseLoc;

// Chosen capture point placement
var vector ChosenLocs[6];
var rotator ChosenRots[6];
var int ChosenCount;

//=============================================================================
// Initialization & Map Candidate Collection
//=============================================================================

function PostBeginPlay()
{
    local NavigationPoint NP;
    local PlayerStart PS;
    local vector CentralLoc;
    local int i;
    local KOHTimer NewTimer;
    local KOHReplicationInfo GRI;

    Super.PostBeginPlay();

    GRI = KOHReplicationInfo(GameReplicationInfo);
    GRI.NumTimers = PointsToSpawn;

    // 1. Gather potential placement spots from level navigation points
    for (NP = Level.NavigationPointList; NP != None; NP = NP.nextNavigationPoint)
    {
        if (NP.IsA('RageDominationTimer'))
        {
            AddToPool(NP, 0);
            NP.Destroy(); // Clean up existing single-domination timers
        }
        else if (NP.IsA('RageDetonationLock'))
            AddToPool(NP, 1);
        else if (NP.IsA('RageDetPossibleKeyPos'))
            AddToPool(NP, 2);
        else
        {
            PS = PlayerStart(NP);
            if (PS != None)
            {
                if (PS.TeamNumber == 0)
                    BlueBaseLoc = PS.Location;
                else if (PS.TeamNumber == 1)
                    RedBaseLoc = PS.Location;
                else if (PS.TeamNumber == 255 && IsFarFromBases(PS.Location))
                    AddToPool(PS, 2);
            }
        }
    }

    // 2. Select balanced / spaced points from candidate pool
    if (PoolCount <= 0)
        return;

    CentralLoc = (BlueBaseLoc + RedBaseLoc) * 0.5;
    if (bCentralizedSpawning)
    {
        // 1. Central timer (type 0 preferred, or closest to map midpoint)
        PickPoint(CentralLoc, 0);

        // 2. If 2 points requested: pick 1 equidistant neutral point
        if (PointsToSpawn == 2 && ChosenCount < PointsToSpawn)
            PickPoint(CentralLoc, 2);
        // 3. If 3 or more points requested: pick symmetric base locks / spots near bases
        else if (PointsToSpawn >= 3)
        {
            PickPoint(BlueBaseLoc, 1);
            PickPoint(RedBaseLoc, 1);
        }

        // 4. Fill remaining requested points with spaced out candidates
        while (ChosenCount < PointsToSpawn && PoolCount > 0)
        {
            if (!PickPoint(vect(0, 0, 0), 2))
                break;
        }
    }
    else
    {
        // Distributed selection
        while (ChosenCount < PointsToSpawn && PoolCount > 0)
        {
            if (!PickPoint(vect(0, 0, 0)))
                break;
        }
    }

    // Fallback: relax distance if map layout is tight
    while (ChosenCount < PointsToSpawn && PoolCount > 0)
    {
        if (!PickPoint(vect(0, 0, 0),, MinDistance * 0.5))
            break;
    }

    // 3. Spawn the KOHTimer actors at selected spots
    for (i = 0; i < ChosenCount; i++)
    {
        NewTimer = Spawn(class'KOHTimer',,, ChosenLocs[i], ChosenRots[i]);
        if (NewTimer != None)
        {
            NewTimer.PointIndex = i;
            NewTimer.PointName = "Point " $ Chr(65 + i);
            if (GRI != None)
            {
                GRI.TimerList[i] = NewTimer;
                GRI.TimerTeams[i] = 255;
            }
        }
    }

    if (GRI != None)
        GRI.NumTimers = ChosenCount;
}

function bool PickPoint(optional vector RefLoc, optional int PreferredType, optional float DistThreshold)
{
    local int idx;

    if (DistThreshold == 0.0)
        DistThreshold = MinDistance;

    idx = PickBestCandidate(RefLoc, DistThreshold, PreferredType);
    if (idx == -1 && DistThreshold < MinDistance)
        idx = 0; // Take whatever candidate is in pool

    if (idx != -1)
    {
        AddChosenPoint(idx);
        return true;
    }

    return false;
}

function int PickBestCandidate(vector RefLoc, float DistThreshold, optional int PreferredType)
{
    local int i, bestIdx;
    local float dist, bestDist;

    bestIdx = -1;
    bestDist = 999999.0;

    for (i = 0; i < PoolCount; i++)
    {
        if (IsFarFromChosen(PoolLoc[i], DistThreshold))
        {
            if (RefLoc != vect(0,0,0))
                dist = VSize(PoolLoc[i] - RefLoc);
            else
                dist = FRand() * 1000.0;

            if (PoolType[i] == PreferredType)
                dist -= 5000.0; // Preference bonus for matching category

            if (dist < bestDist)
            {
                bestDist = dist;
                bestIdx = i;
            }
        }
    }

    return bestIdx;
}

function AddChosenPoint(int Idx)
{
    if (Idx < 0 || Idx >= PoolCount || ChosenCount >= 6)
        return;

    ChosenLocs[ChosenCount] = PoolLoc[Idx];
    ChosenRots[ChosenCount] = PoolRot[Idx];
    ChosenCount++;
    RemoveFromPool(Idx);
}

function bool IsFarFromBases(vector Loc)
{
    local PlayerStart PS;
    foreach RadiusActors(class'PlayerStart', PS, MinDistance * 2, Loc)
    {
        if (PS.TeamNumber != 255)
            return false;
    }

    return true;
}

function bool IsFarFromChosen(vector Loc, float CheckDist)
{
    local int i;
    for (i = 0; i < ChosenCount; i++)
    {
        if (VSize(Loc - ChosenLocs[i]) < CheckDist)
            return false;
    }

    return true;
}

function AddToPool(NavigationPoint NP, int type)
{
    if (PoolCount >= ArrayCount(PoolLoc))
        return;

    PoolLoc[PoolCount] = NP.Location;
    PoolRot[PoolCount] = NP.Rotation;
    PoolType[PoolCount] = type;
    PoolCount++;
}

function RemoveFromPool(int Idx)
{
    local int i;
    if (Idx < 0 || Idx >= PoolCount)
        return;

    for (i = Idx; i < PoolCount - 1; i++)
    {
        PoolLoc[i] = PoolLoc[i + 1];
        PoolRot[i] = PoolRot[i + 1];
        PoolType[i] = PoolType[i + 1];
    }

    PoolCount--;
}

//=============================================================================
// Scoring & Match State
//=============================================================================

function ScoreTimer(Pawn Scorer, KOHTimer TheTimer)
{
    local KOHReplicationInfo GRI;

    Super.TeamScore(Scorer);

    if (Scorer.PlayerReplicationInfo != None)
        Scorer.PlayerReplicationInfo.Score += 2; // Bonus for capturing point

    GRI = KOHReplicationInfo(GameReplicationInfo);
    if (GRI != None && TheTimer.PointIndex >= 0 && TheTimer.PointIndex < GRI.NumTimers)
        GRI.TimerTeams[TheTimer.PointIndex] = TheTimer.Team;

    BroadcastLocalizedMessage(class'KOHMessage', TheTimer.PointIndex, Scorer.PlayerReplicationInfo, None, TheTimer);
}

function Timer()
{
    local KOHReplicationInfo GRI;
    local int i;

    Super.Timer();

    if (!bGameEnded)
    {
        GRI = KOHReplicationInfo(GameReplicationInfo);
        if (GRI != None)
        {
            // Award 1 point per second for each controlled capture point
            for (i = 0; i < GRI.NumTimers; i++)
            {
                if (GRI.TimerList[i] != None && GRI.TimerList[i].Team != 255)
                {
                    Teams[GRI.TimerList[i].Team].Score += 1;
                    GRI.TimerList[i].TeamTimes[GRI.TimerList[i].Team] += 1;
                    GRI.TimerTeams[i] = GRI.TimerList[i].Team;
                }
            }

            // Check goal score victory condition
            if (Teams[0].Score >= GoalTeamScore || Teams[1].Score >= GoalTeamScore)
                EndGame("scoretarget");
        }
    }
}

function bool SetEndCams(string Reason)
{
    local RageTeamInfo BestTeam;
    local Pawn P, XNextPawn;
    local PlayerPawn Player;
    local KOHReplicationInfo GRI;

    GRI = KOHReplicationInfo(GameReplicationInfo);

    if (Teams[0].Score == Teams[1].Score)
    {
        BroadcastLocalizedMessage(class'KOHMessage', 0, None, None, None);
        BestTeam = None;
        GameReplicationInfo.GameEndedComments = DrawMessage @ GameEndedMessage;
    }
    else if (Teams[0].Score > Teams[1].Score)
    {
        BestTeam = Teams[0];
        GameReplicationInfo.GameEndedComments = TeamPrefix @ BestTeam.TeamName @ GameEndedMessage;
    }
    else
    {
        BestTeam = Teams[1];
        GameReplicationInfo.GameEndedComments = TeamPrefix @ BestTeam.TeamName @ GameEndedMessage;
    }

    EndTime = Level.TimeSeconds + 3.0;
    if (bMissionGame && RageConsole(RatedPlayer.Player.Console) != None)
        RageConsole(RatedPlayer.Player.Console).LevelCompletedTime = GameReplicationInfo.ElapsedTime;

    for (P = Level.PawnList; P != None; P = XNextPawn)
    {
        XNextPawn = P.NextPawn;
        Player = PlayerPawn(P);

        if (Player != None)
        {
            if (BestTeam != None)
                PlayWinMessage(Player, (Player.PlayerReplicationInfo.Team == BestTeam.TeamIndex));

            Player.bBehindView = true;
            if (GRI != None && GRI.TimerList[0] != None)
                Player.ViewTarget = GRI.TimerList[0];

            Player.ClientGameEnded();
        }

        P.GotoState('GameEnded');
    }

    bGameEnded = true;
    RageGameEnd();

    return true;
}

//=============================================================================
// Bot AI: Multi-Point Coordination & Objective Reaching
//=============================================================================

function int CountAttackersFor(KOHTimer aTimer, byte BotTeam, Pawn ExcludeBot)
{
    local Pawn P;
    local RageBot RB;
    local int Count;

    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        RB = RageBot(P);
        if (
            RB != None && RB != ExcludeBot && RB.bIsPlayer &&
            RB.PlayerReplicationInfo != None && RB.PlayerReplicationInfo.Team == BotTeam &&
            RB.Orders != 'Defend' &&
            (RB.FinalTarget == aTimer || RB.MoveTarget == aTimer || RB.OrderObject == aTimer)
        )
            Count++;
    }

    return Count;
}

function int CountDefendersFor(KOHTimer aTimer, byte BotTeam, Pawn ExcludeBot)
{
    local Pawn P;
    local RageBot RB;
    local int Count;

    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        RB = RageBot(P);
        if (
            RB != None && RB != ExcludeBot && RB.bIsPlayer &&
            RB.PlayerReplicationInfo != None && RB.PlayerReplicationInfo.Team == BotTeam &&
            RB.Orders == 'Defend' &&
            (RB.OrderObject == aTimer || RB.FinalTarget == aTimer)
        )
            Count++;
    }

    return Count;
}

function KOHTimer PickBestTimerForBot(RageBot aBot, bool bAttack)
{
    local KOHReplicationInfo GRI;
    local KOHTimer aTimer, BestTimer;
    local byte BotTeam;
    local int i, Attackers, Defenders;
    local float Score, BestScore, Dist;

    GRI = KOHReplicationInfo(GameReplicationInfo);
    if (GRI == None || GRI.NumTimers <= 0)
        return None;

    BotTeam = aBot.PlayerReplicationInfo.Team;
    BestScore = -999999.0;
    BestTimer = None;

    if (bAttack)
    {
        // 1. Look for enemy or neutral timers to capture
        for (i = 0; i < GRI.NumTimers; i++)
        {
            aTimer = GRI.TimerList[i];
            if (aTimer != None && aTimer.Team != BotTeam)
            {
                Attackers = CountAttackersFor(aTimer, BotTeam, aBot);
                Dist = VSize(aBot.Location - aTimer.Location);

                // Group splitting: bias toward pairs of 2, prefer unattended points
                Score = 100.0;
                if (Attackers == 0)
                    Score += 40.0;
                else if (Attackers == 1)
                    Score += 25.0;
                else
                    Score -= (Attackers * 20.0);

                Score -= (Dist * 0.005);
                Score += (FRand() * 10.0); // Jitter to prevent lockstep

                if (Score > BestScore)
                {
                    BestScore = Score;
                    BestTimer = aTimer;
                }
            }
        }

        // If an attack target was found, return it directly
        if (BestTimer != None)
            return BestTimer;
    }

    // 2. Defense or fallback: find owned timer with fewest defenders
    BestScore = -999999.0;
    BestTimer = None;

    for (i = 0; i < GRI.NumTimers; i++)
    {
        aTimer = GRI.TimerList[i];
        if (aTimer != None && aTimer.Team == BotTeam)
        {
            Defenders = CountDefendersFor(aTimer, BotTeam, aBot);
            Dist = VSize(aBot.Location - aTimer.Location);
            Score = 100.0 - (Defenders * 30.0) - (Dist * 0.005) + (FRand() * 10.0);

            if (Score > BestScore)
            {
                BestScore = Score;
                BestTimer = aTimer;
            }
        }
    }

    // 3. Absolute fallback: pick any timer closest to bot
    if (BestTimer == None)
    {
        for (i = 0; i < GRI.NumTimers; i++)
        {
            aTimer = GRI.TimerList[i];
            if (aTimer != None)
            {
                Dist = VSize(aBot.Location - aTimer.Location);
                Score = 1000.0 - Dist;
                if (Score > BestScore)
                {
                    BestScore = Score;
                    BestTimer = aTimer;
                }
            }
        }
    }

    return BestTimer;
}

function SetBotOrders(RBot NewBot)
{
    local RageBot aBot;
    local KOHReplicationInfo GRI;
    local KOHTimer TargetTimer;
    local int OwnedPoints, i;
    local byte BotTeam;

    aBot = RageBot(NewBot);
    if (aBot == None || aBot.PlayerReplicationInfo == None)
    {
        Super.SetBotOrders(NewBot);
        return;
    }

    BotTeam = aBot.PlayerReplicationInfo.Team;
    GRI = KOHReplicationInfo(GameReplicationInfo);

    if (GRI != None)
    {
        for (i = 0; i < GRI.NumTimers; i++)
        {
            if (GRI.TimerList[i] != None && GRI.TimerList[i].Team == BotTeam)
                OwnedPoints++;
        }
    }

    // Allocate ~35% of bots to defend owned points, remaining bots attack
    if (OwnedPoints > 0 && FRand() < 0.35)
    {
        TargetTimer = PickBestTimerForBot(aBot, false);
        aBot.SetOrders('Defend', None, true);
        aBot.OrderObject = TargetTimer;
    }
    else
    {
        TargetTimer = PickBestTimerForBot(aBot, true);
        aBot.SetOrders('Attack', None, true);
        aBot.OrderObject = TargetTimer;
    }
}

function Actor SetDefenseFor(RBot aBot)
{
    local RageBot RB;
    RB = RageBot(aBot);
    if (RB != None)
        return PickBestTimerForBot(RB, false);

    return None;
}

function byte PriorityObjective(RBot aBot)
{
    local KOHReplicationInfo GRI;
    local KOHTimer aTimer;
    local int i;
    local byte BestPri;

    GRI = KOHReplicationInfo(GameReplicationInfo);
    if (GRI == None)
        return 0;

    BestPri = 0;
    for (i = 0; i < GRI.NumTimers; i++)
    {
        aTimer = GRI.TimerList[i];
        if (aTimer != None && aTimer.Team != aBot.PlayerReplicationInfo.Team)
        {
            if ((VSize(aBot.Location - aTimer.Location) < 2000) && aBot.LineOfSightTo(aTimer))
                return 255;

            BestPri = 2;
        }
    }

    return BestPri;
}

function bool FindSpecialAttractionForX(RBot InBot)
{
    local KOHTimer aTimer;
    local bool bOrdered;
    local float Dist;
    local byte BotTeam;
    local RageBot aBot;

    aBot = RageBot(InBot);
    if (aBot == None || aBot.PlayerReplicationInfo == None)
        return false;

    BotTeam = aBot.PlayerReplicationInfo.Team;
    bOrdered = aBot.bSniping || (aBot.Orders == 'Follow') || (aBot.Orders == 'Hold');

    if (aBot.Orders == 'Defend')
        aTimer = PickBestTimerForBot(aBot, false);
    else
        aTimer = PickBestTimerForBot(aBot, true);

    if (aTimer == None)
        return false;

    // In vehicle
    if (aBot.VehicleIn != None)
    {
        if (!aBot.bDriver)
            return false;

        Dist = VSize(FindCarParkFor(aTimer).Location - aBot.Location);
        if (Dist < 1000 && aBot.ActorReachable(aTimer))
        {
            aBot.LeaveVehicle();
            aBot.MoveTarget = aTimer;
            aBot.FinalTarget = aTimer;
            SetAttractionStateFor(aBot);
            return true;
        }
        else
        {
            aBot.MoveTarget = aBot.FindPathTowardVeh(aTimer);
            if (aBot.MoveTarget != None)
            {
                aBot.FinalTarget = aTimer;
                if (!aBot.IsInState('GotoPlaceVehicle'))
                    aBot.GotoState('GotoPlaceVehicle');

                aBot.GotoPlaceTarget = aBot.MoveTarget;
                SetAttractionStateFor(aBot);
                return true;
            }
            else
            {
                aBot.LeaveVehicle();
                if (aBot.RouteCache[0] != None)
                    aBot.MoveTarget = aBot.RouteCache[0];

                SetAttractionStateFor(aBot);
                return (aBot.MoveTarget != None);
            }
        }
    }

    // On foot navigation
    if (!bOrdered)
    {
        // 1. Attacking/Capturing enemy or neutral timer:
        if (aTimer.Team != BotTeam)
        {
            // CRITICAL FIX: If timer is directly reachable, head straight into it to capture!
            if (aBot.ActorReachable(aTimer))
            {
                aBot.MoveTarget = aTimer;
                aBot.FinalTarget = aTimer;
                SetAttractionStateFor(aBot);
                return true;
            }

            // Otherwise pathfind along navigation network toward timer
            aBot.MoveTarget = aBot.FindPathToward(aTimer);
            if (aBot.MoveTarget != None)
            {
                aBot.FinalTarget = aTimer;
                SetAttractionStateFor(aBot);
                return true;
            }
        }
        // 2. Defending owned timer:
        else if (aBot.Orders == 'Defend')
        {
            Dist = VSize(aBot.Location - aTimer.Location);

            // If distant from defended point, move towards it
            if (Dist > 600.0)
            {
                if (aBot.ActorReachable(aTimer))
                {
                    aBot.MoveTarget = aTimer;
                    aBot.FinalTarget = aTimer;
                    SetAttractionStateFor(aBot);
                    return true;
                }

                aBot.MoveTarget = aBot.FindPathToward(aTimer);
                if (aBot.MoveTarget != None)
                {
                    aBot.FinalTarget = aTimer;
                    SetAttractionStateFor(aBot);
                    return true;
                }
            }
            // Close to defended point: guard perimeter
            else if (aBot.Enemy == None)
            {
                if (aBot.FindAmbushSpot())
                {
                    aBot.MoveTarget = aBot.AmbushSpot;
                    aBot.FinalTarget = aBot.AmbushSpot;
                    SetAttractionStateFor(aBot);
                    return true;
                }
            }
        }
    }

    return false;
}

defaultproperties
{
     PointsToSpawn=3
     GoalTeamScore=500
     bCentralizedSpawning=True
     MinDistance=600.000000
     bScoreTeamKills=False
     CurrentOrders(0)=FreeLance
     CurrentOrders(1)=FreeLance
     CurrentOrders(2)=FreeLance
     CurrentOrders(3)=FreeLance
     FragLimit=500
     TimeLimit=0
     InstructionSound=Sound'Announcer.Hold_the_Point'
     RulesMenuType="KOH.screenRulesKOH"
     HUDType=Class'KOH.KOHHUD'
     MapPrefix="KOH-"
     BeaconName="KOH"
     GameName="King of the Hill"
     GameReplicationInfoClass=Class'KOH.KOHReplicationInfo'
}
