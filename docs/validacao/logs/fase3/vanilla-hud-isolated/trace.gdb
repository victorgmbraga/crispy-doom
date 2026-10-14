set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase3/vanilla-hud-isolated/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase3/vanilla-hud-isolated/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase3/vanilla-hud-isolated" "-nosound" "-nogui" "-window" "-warp" "1"
set $gtics = 0
set $hud_draws = 0
set $crysis_thinks = 0
break *CR_HUDDraw
commands
silent
set $hud_draws = $hud_draws + 1
continue
end
break *CR_PlayerThink
commands
silent
set $crysis_thinks = $crysis_thinks + 1
continue
end
break *G_Ticker
commands
silent
set $gtics = $gtics + 1
if $gtics == 60
printf "F3_VANILLA ticks=%d hud_draws=%d crysis_thinks=%d\n", $gtics, $hud_draws, $crysis_thinks
set $pc = (void*)I_Quit
end
continue
end
run