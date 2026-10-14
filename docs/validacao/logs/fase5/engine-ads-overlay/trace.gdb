set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase5/engine-ads-overlay/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase5/engine-ads-overlay/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase5/engine-ads-overlay" "-nosound" "-nogui" "-window" "-crysis" "-crdebug" "-warp" "1" "-nomonsters"
define queue_key
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = $arg0
set variable events[eventhead].data3 = $arg0
set variable eventhead = (eventhead + 1) % 64
end
set $ticks = 0
set $shot_sent = 0
break *D_ProcessEvents
commands
silent
if $ticks == 65 && !$shot_sent && gamestate == GS_LEVEL
set $shot_sent = 1
set variable key_menu_screenshot = 128
queue_key key_menu_screenshot
end
continue
end
break *CR_PlayerThink
commands
silent
set $ticks = $ticks + 1
if $ticks == 5
set variable players[0].readyweapon = wp_chaingun
set variable players[0].pendingweapon = wp_nochange
set variable cr_players[0].weapon.overlay_slot = 0
end
if $ticks == 30
set variable players[0].cmd.buttons2 = 64
end
if $ticks == 32
set variable players[0].cmd.buttons2 = 8
end
if $ticks == 34
set variable players[0].cmd.buttons2 = 0
end
if $ticks >= 40 && $ticks <= 70
set variable players[0].cmd.buttons2 = 2
end
if $ticks == 70
printf "F5_ENGINE overlay=%d suppressor=%d ads=%d sx=%d sy=%d\n", cr_players[0].weapon.overlay_open, cr_players[0].weapon.attachments[2] & 1, cr_players[0].ads, players[0].psprites[0].sx, players[0].psprites[0].sy
end
if $ticks == 75
set $pc = (void*)I_Quit
end
continue
end
run