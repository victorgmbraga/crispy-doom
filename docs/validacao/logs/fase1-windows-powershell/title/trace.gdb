set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-windows-powershell/title/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-windows-powershell/title/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-windows-powershell/title" "-nosound" "-nogui" "-window" "-crysis"
set $ticks = 0
set $demo_attempts = 0
set $title_pages = 0
set $menu_opened = 0
set $menu_sent = 0
break *D_ProcessEvents
commands
silent
if gamestate == GS_DEMOSCREEN && !$menu_sent
set $menu_sent = 1
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = key_menu_activate
set variable events[eventhead].data2 = 0
set variable events[eventhead].data3 = 0
set variable eventhead = (eventhead + 1) % 64
end
continue
end
break G_DeferedPlayDemo
commands
silent
set $demo_attempts = $demo_attempts + 1
continue
end
break G_DoPlayDemo
commands
silent
set $demo_attempts = $demo_attempts + 1
continue
end
break D_DoAdvanceDemo
commands
silent
set $title_pages = $title_pages + 1
continue
end
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
set variable advancedemo = 1
if menuactive
set $menu_opened = 1
end
if $ticks == 20
printf "F1_TITLE ticks=%d pages=%d demo_attempts=%d state=%d active=%d menu_opened=%d\n", $ticks, $title_pages, $demo_attempts, gamestate, cr_level_started, $menu_opened
set $pc = (void*)I_Quit
end
continue
end
run