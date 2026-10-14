set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase2/vanilla-suit-isolated/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase2/vanilla-suit-isolated/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase2/vanilla-suit-isolated" "-nosound" "-nogui" "-window" "-warp" "1"
set $ticks = 0
set $suit_ticks = 0
set $crysis_thinks = 0
break *CR_SuitTick
commands
silent
set $suit_ticks = $suit_ticks + 1
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
set $ticks = $ticks + 1
if $ticks == 60
printf "F2_VANILLA ticks=%d suit_ticks=%d crysis_thinks=%d\n", $ticks, $suit_ticks, $crysis_thinks
set $pc = (void*)I_Quit
end
continue
end
run