set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase4/engine-weapon/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase4/engine-weapon/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase4/engine-weapon" "-nosound" "-nogui" "-window" "-crysis" "-crdebug" "-warp" "1" "-nomonsters"
set $ticks = 0
set $shots = 0
set $shot_mag = -1
set $vanilla_before = -1
set $vanilla_after = -1
set $reload_mag = -1
set $reload_reserve = -1
break *P_LineAttack
commands
silent
set $shots = $shots + 1
continue
end
break *CR_PlayerThink
commands
silent
set $ticks = $ticks + 1
if $ticks == 5
set variable players[0].readyweapon = wp_chaingun
set variable players[0].pendingweapon = wp_nochange
set variable cr_players[0].weapon.magazine[2] = 30
set variable cr_players[0].weapon.reserve[2] = 105
set variable cr_players[0].weapon.next_fire_tic = 0
set $vanilla_before = players[0].ammo[0]
end
if $ticks >= 30 && $ticks <= 38
set variable players[0].cmd.buttons = 1
end
if $ticks == 39
set variable players[0].cmd.buttons = 0
set $shot_mag = cr_players[0].weapon.magazine[2]
set $vanilla_after = players[0].ammo[0]
end
if $ticks == 50
set variable players[0].cmd.buttons2 = 4
end
if $ticks == 55
set variable players[0].cmd.buttons2 = 0
end
if $ticks == 120
set $reload_mag = cr_players[0].weapon.magazine[2]
set $reload_reserve = cr_players[0].weapon.reserve[2]
printf "F4_ENGINE shots_mag=%d attacks=%d vanilla_before=%d vanilla_after=%d reload_mag=%d reload_reserve=%d reloading=%d\n", $shot_mag, $shots, $vanilla_before, $vanilla_after, $reload_mag, $reload_reserve, cr_players[0].weapon.reloading
end
if $ticks == 125
set $pc = (void*)I_Quit
end
continue
end
run