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
// Noise events. Weapons push events here; perception (Phase 6) consumes
// them. Emission captures the position at the instant of the event.
//

#ifndef CR_SOUND_H
#define CR_SOUND_H

#include "doomdef.h"
#include "m_fixed.h"
#include "p_mobj.h"

typedef enum
{
    CR_NOISE_FOOTSTEP = 0,
    CR_NOISE_GUNSHOT,
    CR_NOISE_SUPPRESSED_GUNSHOT,
    CR_NOISE_EXPLOSION,
    CR_NOISE_IMPACT
} cr_noise_type_t;

typedef struct
{
    mobj_t *source;      // May become stale; never dereferenced for position.
    fixed_t x, y;        // Position captured when the event was emitted.
    fixed_t radius;      // Audible radius in map units.
    cr_noise_type_t type;
    int tic;             // Level tic when emitted.
} cr_noise_event_t;

// Emits one noise event. Radius <= 0 is ignored.
void CR_EmitNoise(mobj_t *source, fixed_t x, fixed_t y, fixed_t radius,
                  cr_noise_type_t type);

// Level lifecycle: drop pending events.
void CR_SoundReset(void);
void CR_SoundLevelEnd(void);

// Instrumentation for -crdebug and the test harness.
int CR_SoundNoiseCount(void);
const cr_noise_event_t *CR_SoundLastNoise(void);

#endif
