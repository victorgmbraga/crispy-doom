set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase6/vanilla-ai-isolated/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase6/vanilla-ai-isolated/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase6/vanilla-ai-isolated" "-nosound" "-nogui" "-window" "-warp" "1"
set $ticks = 0
set $spawns = 0
set $thinks = 0
break *CR_AIOnSpawn
commands
silent
set $spawns = $spawns + 1
continue
end
break *CR_AIThink
commands
silent
set $thinks = $thinks + 1
continue
end
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 60
printf "F6_VANILLA ticks=%d spawns=%d thinks=%d registered=%d\n", $ticks, $spawns, $thinks, CR_AIRegisteredCount()
set $pc = (void*)I_Quit
end
continue
end
run