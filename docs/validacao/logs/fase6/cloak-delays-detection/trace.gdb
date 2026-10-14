set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase6/cloak-delays-detection/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase6/cloak-delays-detection/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase6/cloak-delays-detection" "-nosound" "-nogui" "-window" "-crysis" "-crdebug" "-warp" "1" "-nomonsters"
set $ticks = 0
set $kpa = 0
break *CR_PlayerThink
commands
silent
set $ticks = $ticks + 1
if $ticks == 5
set variable players[0].mo->angle = 0
set variable cr_players[0].suit.mode = 3
set variable cr_players[0].suit.energy = 100
set $kpa = (mobj_t*) P_SpawnMobj(players[0].mo->x + 400 * 65536, players[0].mo->y, -2147483648, MT_CR_KPA)
set $kpa->angle = 2147483648
end
if $ticks == 200
printf "F6_CLOAK state=%d suspicion=%d health=%d energy=%d\n", CR_AIStateOf($kpa), CR_AISuspicionOf($kpa), players[0].health, cr_players[0].suit.energy
set $pc = (void*)I_Quit
end
continue
end
run