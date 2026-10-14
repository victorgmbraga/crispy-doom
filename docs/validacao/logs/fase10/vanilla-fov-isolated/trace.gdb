set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase10/vanilla-fov-isolated/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase10/vanilla-fov-isolated/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase10/vanilla-fov-isolated" "-nosound" "-nogui" "-window" "-warp" "1"
set $ticks = 0
set $fov = 0
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 40
set $fov = CR_RenderFOV()
printf "F10_VANILLA fov=%d\n", $fov
set $pc = (void*)I_Quit
end
continue
end
run