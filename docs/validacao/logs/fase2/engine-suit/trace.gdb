set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args "-iwad" "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" "-config" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase2/engine-suit/default.cfg" "-extraconfig" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase2/engine-suit/crispy-doom.cfg" "-savedir" "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase2/engine-suit" "-nosound" "-nogui" "-window" "-crysis" "-crdebug" "-warp" "1" "-nomonsters"
set $ticks = 0
set $cloak_start = 0
set $cloak_energy = 0
set $cloak_broken = 0
set $speed_start = 0
set $speed_energy = 0
set $regen_before = 0
set $regen_after = 0
set $jump_normal = 0
set $strength_jump = 0
set $strength_cost = 0
break *CR_PlayerThink
commands
silent
set $ticks = $ticks + 1
if $ticks == 5
set variable cr_players[0].suit.mode = 3
set variable cr_players[0].suit.energy = 100
set variable cr_players[0].suit.recharge_block_until = 0
set $cloak_start = 100
end
if $ticks >= 5 && $ticks <= 19
set variable players[0].cmd.forwardmove = 25
end
if $ticks == 20
set $cloak_energy = cr_players[0].suit.energy
printf "F2_CLOAK start=%d after15=%d mode=%d\n", $cloak_start, $cloak_energy, cr_players[0].suit.mode
end
if $ticks == 25
set variable players[0].cmd.buttons = 1
end
if $ticks == 30
printf "F2_FIRE mode=%d energy=%d visible=%d\n", cr_players[0].suit.mode, cr_players[0].suit.energy, cr_players[0].suit.cloak_visible
if cr_players[0].suit.mode == 0 && cr_players[0].suit.energy == 0
set $cloak_broken = 1
end
set variable players[0].cmd.buttons = 0
end
if $ticks == 35
set variable cr_players[0].suit.mode = 2
set variable cr_players[0].suit.energy = 100
set variable cr_players[0].suit.recharge_block_until = 0
set $speed_start = 100
end
if $ticks >= 35 && $ticks <= 49
set variable players[0].cmd.buttons2 = players[0].cmd.buttons2 | 1
set variable players[0].cmd.forwardmove = 25
end
if $ticks == 50
set $speed_energy = cr_players[0].suit.energy
printf "F2_SPEED start=%d after15=%d\n", $speed_start, $speed_energy
end
if $ticks == 55
set variable players[0].cmd.buttons2 = 0
set variable players[0].cmd.forwardmove = 0
set variable cr_players[0].suit.mode = 0
set variable cr_players[0].suit.energy = 50
set variable cr_players[0].suit.recharge_block_until = leveltime + 35
set $regen_before = 50
end
if $ticks == 100
set $regen_after = cr_players[0].suit.energy
printf "F2_RECHARGE before=%d after=%d block=%d leveltime=%d\n", $regen_before, $regen_after, cr_players[0].suit.recharge_block_until, leveltime
end
if $ticks == 110
set variable cr_players[0].suit.mode = 1
set variable cr_players[0].suit.energy = 100
set variable players[0].jumpTics = 0
set variable players[0].mo->z = players[0].mo->floorz
set variable players[0].cmd.arti = 128
end
if $ticks == 111
set $strength_jump = players[0].mo->momz
set $strength_cost = 100 - cr_players[0].suit.energy
set variable players[0].cmd.arti = 0
end
if $ticks == 120
set variable cr_players[0].suit.mode = 0
set variable cr_players[0].suit.energy = 100
set variable players[0].jumpTics = 0
set variable players[0].mo->z = players[0].mo->floorz
set variable players[0].cmd.arti = 128
end
if $ticks == 121
set $jump_normal = players[0].mo->momz
set variable players[0].cmd.arti = 0
end
if $ticks == 130
printf "F2_JUMP normal=%d strength=%d cost=%d\n", $jump_normal, $strength_jump, $strength_cost
printf "F2_ENGINE cloak_broken=%d\n", $cloak_broken
set $pc = (void*)I_Quit
end
continue
end
run