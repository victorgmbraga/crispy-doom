set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-windows-powershell/engine-input-menus/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-windows-powershell/engine-input-menus/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-windows-powershell/engine-input-menus" "-nosound" "-nogui" "-window" "-crysis" "-crdebug" "-warp" "1" "-nomonsters"
define queue_key
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = $arg0
set variable events[eventhead].data3 = $arg0
set variable eventhead = (eventhead + 1) % 64
end
define queue_focus
set variable events[eventhead].type = ev_focus
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = 0
set variable events[eventhead].data3 = 0
set variable eventhead = (eventhead + 1) % 64
end
define queue_key_up
set variable events[eventhead].type = ev_keyup
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = 0
set variable events[eventhead].data3 = 0
set variable eventhead = (eventhead + 1) % 64
end
define queue_mouse
set variable mouse_button_state = $arg0
set variable events[eventhead].type = ev_mouse
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = 8
set variable events[eventhead].data3 = 4
set variable eventhead = (eventhead + 1) % 64
end
set $polls = 0
set $producer = 0
set $producer_no_autorun = 0
set $focus_clear = 0
set $menu_clear = 0
set $save_load_blocks = 0
break CR_RejectUnsupported
commands
silent
if feature[0] == 115 && feature[4] == 47
set $save_load_blocks = $save_load_blocks + 1
end
continue
end
break CR_BuildTiccmd
commands
silent
if $polls >= 1 && $polls < 12
if cmd->forwardmove == 25 && cmd->sidemove == 0 && cmd->angleturn != 0 && (cmd->arti & 128) && cmd->lookdir != 0 && !(cmd->buttons & 2)
set $producer = 1
printf "F1_PRODUCER forward=%d side=%d angle=%d jump=%d look=%d use=%d autorun=%d\n", cmd->forwardmove, cmd->sidemove, cmd->angleturn, cmd->arti, cmd->lookdir, cmd->buttons & 2, joybspeed
end
end
if $polls == 19
set $menu_clear = (cmd->forwardmove == 0 && cmd->sidemove == 0 && !(cmd->buttons & 2) && !cr_keys[key_up] && !cr_keys[key_alt_up] && !cr_keys[key_cr_interact] && !cr_keys[key_cr_sprint] && !cr_players[0].buttons_down && mouse_button_state == 0)
end
if $polls == 15
set $producer_no_autorun = (cmd->forwardmove == 25 && cmd->sidemove == 0 && joybspeed == 2)
end
continue
end
break *D_ProcessEvents
commands
silent
if gamestate == GS_LEVEL
set $polls = $polls + 1
if $polls == 1
set variable crispy->jump = 1
set variable crispy->freelook = 1
set variable crispy->mouselook = 1
set variable joybspeed = 20
queue_key key_up
queue_key key_alt_up
queue_key key_cr_sprint
queue_key key_cr_reload
queue_key key_jump
queue_key key_toggleautorun
queue_mouse 2
end
if $polls == 12
queue_focus 0
end
if $polls == 13
set $focus_clear = (cr_players[0].buttons_down == 0 && !cr_players[0].sprinting && !cr_players[0].ads && !gamekeydown[key_up] && !gamekeydown[key_alt_up] && !gamekeydown[key_speed] && !gamekeydown[key_jump] && mouse_button_state == 0)
end
if $polls == 15
set variable joybspeed = 2
queue_focus 1
queue_key key_up
queue_key key_alt_up
queue_key key_cr_interact
queue_key key_cr_sprint
queue_mouse 2
end
if $polls == 16
queue_key key_menu_activate
end
if $polls == 17
queue_key_up key_up
queue_key_up key_alt_up
queue_key_up key_cr_interact
queue_key_up key_cr_sprint
end
if $polls == 18
queue_key key_menu_activate
end
if $polls == 20
queue_key key_menu_save
end
if $polls == 21
queue_key key_menu_confirm
queue_key key_menu_activate
end
if $polls == 24
queue_key key_menu_load
end
if $polls == 25
queue_key key_menu_confirm
queue_key key_menu_activate
end
if $polls == 28
queue_key key_menu_qsave
end
if $polls == 29
queue_key key_menu_confirm
end
if $polls == 32
queue_key key_menu_qload
end
if $polls == 33
queue_key key_menu_confirm
end
if $polls == 40
printf "F1_INPUT polls=%d producer=%d producer_no_autorun=%d focus_clear=%d menu_clear=%d menu_blocks=%d save_entry=%d action=%d\n", $polls, $producer, $producer_no_autorun, $focus_clear, $menu_clear, $save_load_blocks, saveStringEnter, gameaction
set $pc = (void*)I_Quit
end
end
continue
end
run