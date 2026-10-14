set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase6/noise-unsuppressed/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase6/noise-unsuppressed/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase6/noise-unsuppressed" "-nosound" "-nogui" "-window" "-crysis" "-crdebug" "-warp" "1" "-nomonsters"
set $ticks = 0
set $kpa = 0
set $before = -1
break *CR_PlayerThink
commands
silent
set $ticks = $ticks + 1
if $ticks == 5
set variable players[0].mo->angle = 0

set $kpa = (mobj_t*) P_SpawnMobj(players[0].mo->x + 600 * 65536, players[0].mo->y, -2147483648, MT_CR_KPA)
set $kpa->angle = 0
end
if $ticks == 20
set $before = CR_AIStateOf($kpa)
end
if $ticks >= 30 && $ticks <= 34
set variable players[0].cmd.buttons = 1
end
if $ticks == 80
printf "F6_NOISE before=%d after=%d suspicion=%d noises=%d\n", $before, CR_AIStateOf($kpa), CR_AISuspicionOf($kpa), CR_SoundNoiseCount()
set $pc = (void*)I_Quit
end
continue
end
run