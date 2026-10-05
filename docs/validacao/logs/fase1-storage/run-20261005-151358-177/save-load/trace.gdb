set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args -iwad "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" -config "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-storage/run-20261005-151358-177/save-load/default.cfg" -extraconfig "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-storage/run-20261005-151358-177/save-load/crispy-doom.cfg" -savedir "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-storage/run-20261005-151358-177/save-load" -window -nosound -nogui -warp 1 -nomonsters
set $ticks = 0
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 15
set variable players[0].health = 77
set variable players[0].mo->health = 77
end
if $ticks == 20
set variable savegameslot = 0
set {char[16]} savedescription = "F1 VANILLA TEST"
set variable gameaction = ga_savegame
end
if $ticks == 25
printf "F1_STORAGE saved action=%d health=%d\n", gameaction, players[0].health
set variable players[0].health = 17
set variable players[0].mo->health = 17
end
if $ticks == 30
set variable gameaction = ga_loadgame
end
if $ticks == 31
printf "F1_STORAGE loaded action=%d health=%d mobjhealth=%d map=%d\n", gameaction, players[0].health, players[0].mo->health, gamemap
end
if $ticks == 45
set $pc = (void*)I_Quit
end
continue
end
run