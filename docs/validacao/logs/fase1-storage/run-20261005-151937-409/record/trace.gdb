set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args -iwad "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" -config "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-storage/run-20261005-151937-409/record/default.cfg" -extraconfig "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-storage/run-20261005-151937-409/record/crispy-doom.cfg" -savedir "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-storage/run-20261005-151937-409/record" -window -nosound -nogui -warp 1 -nomonsters -record "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-storage/run-20261005-151937-409/vanilla-record"
set $ticks = 0
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks >= 10 && $ticks < 35
set variable netcmds[0].forwardmove = 25
end
if $ticks >= 36 && $ticks < 50
set variable netcmds[0].angleturn = 512
end
if $ticks >= 45 && $ticks < 65
set variable netcmds[0].buttons = 1
end
if $ticks == 70
set $pc = (void*)I_Quit
end
continue
end
break I_Quit
commands
silent
printf "STORAGE_SNAPSHOT map=%d gametic=%d leveltime=%d x=%d y=%d z=%d angle=%u health=%d bullets=%d rng=%d\n", gamemap, gametic, leveltime, players[0].mo->x, players[0].mo->y, players[0].mo->z, players[0].mo->angle, players[0].health, players[0].ammo[0], prndindex
continue
end
run