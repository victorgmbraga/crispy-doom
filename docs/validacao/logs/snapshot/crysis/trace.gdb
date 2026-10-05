set pagination off
set confirm off
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args -iwad "C:/Users/victor.braga/crysis-crispy-doom/content/iwad/freedoom2.wad" -config "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/snapshot/crysis/default.cfg" -extraconfig "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/snapshot/crysis/crispy-doom.cfg" -savedir "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/snapshot/crysis" -nosound -nogui -window -playdemo "C:/Users/victor.braga/crysis-crispy-doom/docs/validacao/logs/smoke/fase0-smoke.lmp" -crysis
break I_Quit
commands
silent
printf "SNAPSHOT map=%d gametic=%d leveltime=%d x=%d y=%d z=%d angle=%u health=%d mobjhealth=%d bullets=%d rng=%d paused=%d\n", gamemap, gametic, leveltime, players[0].mo->x, players[0].mo->y, players[0].mo->z, players[0].mo->angle, players[0].health, players[0].mo->health, players[0].ammo[0], prndindex, paused
continue
end
run