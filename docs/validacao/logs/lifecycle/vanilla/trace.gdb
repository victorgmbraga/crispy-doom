set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args -iwad "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" -config "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/lifecycle/vanilla/default.cfg" -extraconfig "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/lifecycle/vanilla/crispy-doom.cfg" -savedir "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/lifecycle/vanilla" -nosound -nogui -window -warp 1 -nomonsters
set $ticks = 0
set $newgames = 0
set $levels = 0
set $crnew = 0
set $crstart = 0
set $crclean = 0
set $crticks = 0
set $menu_frozen = 0
set $pause_frozen = 0
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
break CR_NewGame
commands
silent
set $crnew = $crnew + 1
continue
end
break CR_LevelStart
commands
silent
set $crstart = $crstart + 1
continue
end
break CR_LevelEnd
commands
silent
if cr_level_started
set $crclean = $crclean + 1
end
continue
end
break CR_Ticker
commands
silent
set $crticks = $crticks + 1
continue
end
break SDL_Quit
commands
silent
if $quit_requested
printf "LIFECYCLE_FINAL map=%d ticks=%d newgames=%d levels=%d crnew=%d crstart=%d crclean=%d crticks=%d menu_frozen=%d pause_frozen=%d level_active=%d\n", gamemap, $ticks, $newgames, $levels, $crnew, $crstart, $crclean, $crticks, $menu_frozen, $pause_frozen, cr_level_started
end
continue
end
break G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 20
set $menu_leveltime = leveltime
set $menu_crticks = $crticks
set variable menuactive = 1
end
if $ticks == 30
set $menu_frozen = (leveltime == $menu_leveltime && $crticks == $menu_crticks)
set variable menuactive = 0
end
if $ticks == 40
set $pause_leveltime = leveltime
set $pause_crticks = $crticks
set variable paused = 1
end
if $ticks == 45
set $pause_frozen = (leveltime == $pause_leveltime && $crticks == $pause_crticks)
set variable paused = 0
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
if $ticks == 110
set variable gameaction = ga_completed
end
if $ticks == 120
set variable gameaction = ga_worlddone
end
if $ticks == 150
set $quit_requested = 1
set $pc = I_Quit
end
continue
end
run