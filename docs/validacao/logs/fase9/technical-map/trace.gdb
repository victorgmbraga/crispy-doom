set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase9/technical-map/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase9/technical-map/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase9/technical-map" "-nosound" "-nogui" "-window" "-crysis" "-crdebug" "-file" "C:/Users/victor.braga/crysis-crispy-doom/content/pwad/crysis-technical.wad" "-warp" "1"
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
set $kpa = -1
set $o1line = 20
set $o2line = 1247
set $jamline = 835
set $exitline = 14
set $shot_sent = 0
break *D_ProcessEvents
commands
silent
if $ticks == 15 && !$shot_sent && gamestate == GS_LEVEL
set $shot_sent = 1
set variable key_menu_screenshot = 128
queue_key key_menu_screenshot
end
continue
end
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 10
set $kpa = CR_AIRegisteredCount()
printf "F9_SPECIALS l301tag0=%d l302=%d l303=%d o1idx=%d o2idx=%d jamidx=%d exitidx=%d\n", 0, 0, 0, $o1line, $o2line, $jamline, $exitline
end
if $ticks == 20
call P_UseSpecialLine(players[0].mo, &lines[$o1line], 0)
call P_UseSpecialLine(players[0].mo, &lines[$o1line], 0)
call P_UseSpecialLine(players[0].mo, &lines[$o2line], 0)
call P_UseSpecialLine(players[0].mo, &lines[$o2line], 0)
call P_UseSpecialLine(players[0].mo, &lines[$jamline], 0)
printf "F9_MAP kpa=%d o1=%d o2=%d o3=%d canexit=%d exitline_special=%d\n", $kpa, CR_ObjectiveState(1), CR_ObjectiveState(2), CR_ObjectiveState(3), CR_ObjectiveCanExit(), lines[$exitline].special
end
if $ticks == 30
call P_UseSpecialLine(players[0].mo, &lines[$exitline], 0)
end
if $ticks > 35 && gamestate != GS_LEVEL
if $ticks == 40 || $ticks == 50 || $ticks == 60
queue_key key_fire
end
if $ticks == 45 || $ticks == 55 || $ticks == 65
queue_key_up key_fire
end
end
if $ticks == 120
printf "F9_EXIT map=%d o4=%d state=%d\n", gamemap, CR_ObjectiveState(4), gamestate
set $pc = (void*)I_Quit
end
continue
end
run