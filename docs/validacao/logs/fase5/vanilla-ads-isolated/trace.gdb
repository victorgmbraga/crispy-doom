set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase5/vanilla-ads-isolated/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase5/vanilla-ads-isolated/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase5/vanilla-ads-isolated" "-nosound" "-nogui" "-window" "-warp" "1"
set $ticks = 0
set $overlay = 0
set $weapon_ticks = 0
break *CR_WeaponTick
commands
silent
set $weapon_ticks = $weapon_ticks + 1
continue
end
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 40
set $overlay = cr_players[0].weapon.overlay_open
printf "F5_VANILLA ticks=%d weapon_ticks=%d overlay=%d\n", $ticks, $weapon_ticks, $overlay
set $pc = (void*)I_Quit
end
continue
end
run