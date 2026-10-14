set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase9/technical-map-refuse/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase9/technical-map-refuse/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase9/technical-map-refuse" "-nosound" "-nogui" "-window" "-crysis" "-crdebug" "-file" "C:/Users/victor.braga/crysis-crispy-doom/content/pwad/crysis-technical.wad" "-warp" "1"
set $ticks = 0
set $exitline = 14
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 10
call P_UseSpecialLine(players[0].mo, &lines[$exitline], 0)
end
if $ticks == 40
printf "F9_REFUSE map=%d o4=%d state=%d\n", gamemap, CR_ObjectiveState(4), gamestate
set $pc = (void*)I_Quit
end
continue
end
run