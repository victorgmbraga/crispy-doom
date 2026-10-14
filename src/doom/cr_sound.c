//
// Copyright(C) 2026 Crysis Contact Demake contributors
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// Noise events and their sparse dispatch. One owner: CR_EmitNoise callers
// only push; consumers read through CR_SoundLastNoise until Phase 6 adds
// the perception listeners.
//

#include <stdio.h>
#include <string.h>

#include "doomdef.h"
#include "doomstat.h"

#include "cr_defs.h"
#include "cr_ai.h"
#include "cr_game.h"
#include "cr_sound.h"

static cr_noise_event_t cr_last_noise;
static int cr_noise_count;

void CR_EmitNoise(mobj_t *source, fixed_t x, fixed_t y, fixed_t radius,
                  cr_noise_type_t type)
{
    if (!CR_IsActive() || radius <= 0)
    {
        return;
    }

    cr_last_noise.source = source;
    cr_last_noise.x = x;
    cr_last_noise.y = y;
    cr_last_noise.radius = radius;
    cr_last_noise.type = type;
    cr_last_noise.tic = leveltime;
    ++cr_noise_count;

    if (CR_DebugEnabled())
    {
        printf(CR_LOG_PREFIX " noise type=%d x=%d y=%d radius=%d tic=%d\n",
               (int) type, x, y, radius, leveltime);
    }

    // Sparse dispatch: perception reacts when the event happens.
    CR_AIDispatchNoise(&cr_last_noise);
}

void CR_SoundReset(void)
{
    memset(&cr_last_noise, 0, sizeof(cr_last_noise));
    cr_noise_count = 0;
}

void CR_SoundLevelEnd(void)
{
    // Events never survive the level they were emitted in.
    memset(&cr_last_noise, 0, sizeof(cr_last_noise));
}

int CR_SoundNoiseCount(void)
{
    return cr_noise_count;
}

const cr_noise_event_t *CR_SoundLastNoise(void)
{
    return &cr_last_noise;
}
