# MF-mods

Mods should be placed in the MobileForces folder to be able to be compiled, in the case of ZombieMode, run this from the System folder in MobileForces

```
rm ZombieGame.u; wine ucc make
```

Then to start the game with it run a command like this

```
wine MobileForces.exe mf-polar?game=ZombieGame.ZombieGame?mutator=mutPack.AddWeaps
```

Or combine both in a single command for rapid testing like

```
rm ZombieGame.u; wine ucc make && wine MobileForces.exe mf-polar?game=ZombieGame.ZombieGame?mutator=mutPack.AddWeaps
```
