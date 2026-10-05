set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-windows-powershell/engine-state-lifecycle/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-windows-powershell/engine-state-lifecycle/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-windows-powershell/engine-state-lifecycle" "-nosound" "-nogui" "-window" "-crysis" "-crdebug" "-warp" "1" "-nomonsters"
set $ticks = 0
set $simticks = 0
set $newgames = 0
set $levels = 0
set $resets = 0
set $menu_frozen = 0
set $pause_frozen = 0
set $expect_reset = 0
set $quit_requested = 0
break G_InitNew
commands
silent
set $newgames = $newgames + 1
continue
end
break P_SetupLevel
commands
silent
set $levels = $levels + 1
continue
end
break *CR_Ticker
commands
silent
set $simticks = $simticks + 1
if $expect_reset
if cr_players[0].initialized && cr_players[0].buttons_down == 0 && cr_players[0].buttons_pressed == 0 && cr_players[0].buttons_released == 0 && !cr_players[0].sprinting && !cr_players[0].ads && !cr_players[0].crouching
set $resets = $resets + 1
end
set $expect_reset = 0
end
if $simticks == 1
set variable players[0].cmd.buttons2 = 255
end
if $simticks == 2
printf "F1_ENGINE first down=%d pressed=%d released=%d sprint=%d ads=%d crouch=%d\n", cr_players[0].buttons_down, cr_players[0].buttons_pressed, cr_players[0].buttons_released, cr_players[0].sprinting, cr_players[0].ads, cr_players[0].crouching
set variable players[0].cmd.buttons2 = 255
end
if $simticks == 3
printf "F1_ENGINE held down=%d pressed=%d released=%d\n", cr_players[0].buttons_down, cr_players[0].buttons_pressed, cr_players[0].buttons_released
set variable players[0].cmd.buttons2 = 0
end
if $simticks == 4
printf "F1_ENGINE release down=%d pressed=%d released=%d\n", cr_players[0].buttons_down, cr_players[0].buttons_pressed, cr_players[0].buttons_released
set variable players[0].cmd.buttons2 = 255
end
if $simticks == 5
printf "F1_ENGINE repress down=%d pressed=%d released=%d\n", cr_players[0].buttons_down, cr_players[0].buttons_pressed, cr_players[0].buttons_released
end
continue
end
break SDL_Quit
commands
silent
if $quit_requested
printf "F1_LIFECYCLE map=%d ticks=%d newgames=%d levels=%d resets=%d menu_frozen=%d pause_frozen=%d active=%d demo=%d recording=%d action=%d\n", gamemap, $ticks, $newgames, $levels, $resets, $menu_frozen, $pause_frozen, cr_level_started, demoplayback, demorecording, gameaction
end
continue
end
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 30
set $menu_leveltime = leveltime
set $menu_simticks = $simticks
set variable menuactive = 1
end
if $ticks == 40
set $menu_frozen = (leveltime == $menu_leveltime && $simticks == $menu_simticks)
set variable menuactive = 0
end
if $ticks == 50
set $pause_leveltime = leveltime
set $pause_simticks = $simticks
set variable paused = 1
end
if $ticks == 55
set $pause_frozen = (leveltime == $pause_leveltime && $simticks == $pause_simticks)
set variable paused = 0
end
if $ticks == 60 || $ticks == 90 || $ticks == 140
set variable cr_players[0].buttons_down = 255
set variable cr_players[0].buttons_pressed = 255
set variable cr_players[0].buttons_released = 255
set variable cr_players[0].sprinting = 1
set variable cr_players[0].ads = 1
set variable cr_players[0].crouching = 1
set $expect_reset = 1
end
if $ticks == 60
set variable d_skill = gameskill
set variable d_episode = gameepisode
set variable d_map = gamemap
set variable gameaction = ga_newgame
end
if $ticks == 90
set variable gameaction = ga_loadlevel
end
if $ticks == 100
set variable gameaction = ga_savegame
end
if $ticks == 110
set variable gameaction = ga_loadgame
end
if $ticks == 120
set variable gameaction = ga_playdemo
end
if $ticks == 130
set variable gameaction = ga_completed
end
if $ticks == 140
set variable gameaction = ga_worlddone
end
if $ticks == 150
set $quit_requested = 1
set $pc = (void*)I_Quit
end
continue
end
run