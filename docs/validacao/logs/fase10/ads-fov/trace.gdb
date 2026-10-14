set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase10/ads-fov/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase10/ads-fov/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase10/ads-fov" "-nosound" "-nogui" "-window" "-crysis" "-crdebug" "-warp" "1" "-nomonsters"
define queue_key
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = $arg0
set variable events[eventhead].data3 = $arg0
set variable eventhead = (eventhead + 1) % 64
end
set $ticks = 0
set $fov_ads = 0
set $fov_scope = 0
set $fov_off = 0
set $shot_sent = 0
break *D_ProcessEvents
commands
silent
if $ticks == 58 && !$shot_sent && gamestate == GS_LEVEL
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
if $ticks == 30
set variable players[0].readyweapon = wp_chaingun
set variable players[0].pendingweapon = wp_nochange
end
if $ticks >= 40 && $ticks <= 60
set variable players[0].cmd.buttons2 = 2
end
if $ticks == 55
set $fov_ads = CR_RenderFOV()
set variable cr_players[0].weapon.attachments[2] = 4
end
if $ticks == 60
set $fov_scope = CR_RenderFOV()
end
if $ticks == 65
set variable players[0].cmd.buttons2 = 0
end
if $ticks == 75
set $fov_off = CR_RenderFOV()
printf "F10_FOV ads=%d scope=%d off=%d\n", $fov_ads, $fov_scope, $fov_off
end
if $ticks == 80
set $pc = (void*)I_Quit
end
continue
end
run