set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase8/mission-objectives/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase8/mission-objectives/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase8/mission-objectives" "-nosound" "-nogui" "-window" "-crysis" "-crdebug" "-warp" "1" "-nomonsters"
define queue_key
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = $arg0
set variable events[eventhead].data3 = $arg0
set variable eventhead = (eventhead + 1) % 64
end
define queue_key_up
set variable events[eventhead].type = ev_keyup
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = 0
set variable events[eventhead].data3 = 0
set variable eventhead = (eventhead + 1) % 64
end
set $ticks = 0
set $refuse_map = 0
set $shot_sent = 0
set $wi_sent = 0
break *D_ProcessEvents
commands
silent
if $ticks == 52 && !$shot_sent && gamestate == GS_LEVEL
set $shot_sent = 1
set variable key_menu_screenshot = 128
queue_key key_menu_screenshot
end
if $ticks > 65 && gamestate != GS_LEVEL
if $ticks == 70 || $ticks == 80 || $ticks == 90
queue_key key_fire
end
if $ticks == 75 || $ticks == 85 || $ticks == 95
queue_key_up key_fire
end
end
continue
end
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 20
set variable lines[0].special = 302
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
set $refuse_map = gamemap
end
if $ticks == 25
set variable lines[0].special = 301
set variable lines[0].tag = 1
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
end
if $ticks == 30
set variable lines[0].special = 301
set variable lines[0].tag = 1
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
end
if $ticks == 35
set variable lines[0].special = 301
set variable lines[0].tag = 2
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
end
if $ticks == 38
set variable lines[0].special = 301
set variable lines[0].tag = 2
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
end
if $ticks == 42
set variable lines[0].special = 303
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
end
if $ticks == 50
printf "F8_STATES o1=%d o2=%d o3=%d o4=%d canexit=%d map=%d\n", CR_ObjectiveState(1), CR_ObjectiveState(2), CR_ObjectiveState(3), CR_ObjectiveState(4), CR_ObjectiveCanExit(), gamemap
end
if $ticks == 60
set variable lines[0].special = 302
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
end
if $ticks == 120
printf "F8_EXIT refuse_map=%d o4=%d map=%d state=%d\n", $refuse_map, CR_ObjectiveState(4), gamemap, gamestate
set $pc = (void*)I_Quit
end
continue
end
run