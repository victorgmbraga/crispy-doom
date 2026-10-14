set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase3/engine-regen-hud/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase3/engine-regen-hud/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase3/engine-regen-hud" "-nosound" "-nogui" "-window" "-crysis" "-crdebug" "-warp" "1" "-nomonsters"
define queue_key
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = $arg0
set variable events[eventhead].data3 = $arg0
set variable eventhead = (eventhead + 1) % 64
end
set $gtics = 0
set $ptics = 0
set $hud_draws = 0
set $regen_after = 0
set $mobj_health = 0
set $pause_health = -1
set $pause_frozen = 0
set $shot_sent = 0
break *G_Ticker
commands
silent
set $gtics = $gtics + 1
if $gtics == 5
set variable players[0].health = 60
set variable players[0].mo->health = 60
set variable cr_players[0].last_damage_tic = leveltime
end
if $gtics == 200
set $regen_after = players[0].health
set $mobj_health = players[0].mo->health
printf "F3_REGEN after195=%d mobj=%d\n", $regen_after, $mobj_health
end
if $gtics == 210
set variable paused = 1
set $pause_health = players[0].health
end
if $gtics == 240
set $pause_frozen = (players[0].health == $pause_health)
set variable paused = 0
printf "F3_PAUSE health_before=%d frozen=%d\n", $pause_health, $pause_frozen
end
if $gtics == 300
printf "F3_HUD draws=%d energy=%d mode=%d\n", $hud_draws, cr_players[0].suit.energy, cr_players[0].suit.mode
set $pc = (void*)I_Quit
end
continue
end
break *CR_HUDDraw
commands
silent
set $hud_draws = $hud_draws + 1
continue
end
break *D_ProcessEvents
commands
silent
if $gtics == 280 && !$shot_sent && gamestate == GS_LEVEL
set $shot_sent = 1
set variable key_menu_screenshot = 128
set variable png_screenshots = 1
queue_key key_menu_screenshot
end
continue
end
run