set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase4/vanilla-weapon-isolated/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase4/vanilla-weapon-isolated/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase4/vanilla-weapon-isolated" "-nosound" "-nogui" "-window" "-warp" "1"
define queue_key
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = $arg0
set variable events[eventhead].data3 = $arg0
set variable eventhead = (eventhead + 1) % 64
end
set $ticks = 0
set $cr_fires = 0
set $cr_ticks = 0
set $ammo_before = -1
set $key_sent = 0
break *CR_WeaponFire
commands
silent
set $cr_fires = $cr_fires + 1
continue
end
break *CR_WeaponTick
commands
silent
set $cr_ticks = $cr_ticks + 1
continue
end
break *D_ProcessEvents
commands
silent
if $ticks == 20 && !$key_sent
set $key_sent = 1
set $ammo_before = players[0].ammo[0]
queue_key key_fire
end
continue
end
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 60
printf "F4_VANILLA cr_fires=%d cr_ticks=%d ammo_before=%d ammo_after=%d\n", $cr_fires, $cr_ticks, $ammo_before, players[0].ammo[0]
set $pc = (void*)I_Quit
end
continue
end
run