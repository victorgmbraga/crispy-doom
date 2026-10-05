set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args -iwad "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" -config "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-storage/run-20261005-151937-409/play-recorded/default.cfg" -extraconfig "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-storage/run-20261005-151937-409/play-recorded/crispy-doom.cfg" -savedir "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-storage/run-20261005-151937-409/play-recorded" -window -nosound -nogui -playdemo "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/fase1-storage/run-20261005-151937-409/vanilla-record.lmp"
break I_Quit
commands
silent
printf "STORAGE_SNAPSHOT map=%d gametic=%d leveltime=%d x=%d y=%d z=%d angle=%u health=%d bullets=%d rng=%d\n", gamemap, gametic, leveltime, players[0].mo->x, players[0].mo->y, players[0].mo->z, players[0].mo->angle, players[0].health, players[0].ammo[0], prndindex
continue
end
run