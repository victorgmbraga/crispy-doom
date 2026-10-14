set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase8/vanilla-objectives-isolated/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase8/vanilla-objectives-isolated/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase8/vanilla-objectives-isolated" "-nosound" "-nogui" "-window" "-warp" "1"
set $ticks = 0
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 30
set variable lines[0].special = 303
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
set variable lines[0].special = 301
set variable lines[0].tag = 1
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
printf "F8_VANILLA o1=%d o3=%d map=%d\n", CR_ObjectiveState(1), CR_ObjectiveState(3), gamemap
end
if $ticks == 40
set $pc = (void*)I_Quit
end
continue
end
run