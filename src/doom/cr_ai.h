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
// Crysis soldier perception and behavior. External registry created on
// spawn and removed before the mobj is freed; no per-tic heap.
//

#ifndef CR_AI_H
#define CR_AI_H

#include "doomdef.h"
#include "m_fixed.h"
#include "p_mobj.h"
#include "cr_sound.h"

typedef enum
{
    CR_AI_PATROL = 0,
    CR_AI_SUSPICIOUS,
    CR_AI_INVESTIGATE,
    CR_AI_ALERT,
    CR_AI_COMBAT,
    CR_AI_SEARCH,
    CR_AI_RETURN
} cr_ai_state_t;

#define CR_AI_MAX_ACTORS 64

// Lifecycle: called from CR_NewGame/CR_LevelStart/CR_LevelEnd.
void CR_AIReset(void);
void CR_AILevelEnd(void);

// Spawn/removal registry. Spawn auto-registers KPA actors; actors of other
// types are ignored.
void CR_AIOnSpawn(mobj_t *mo);
void CR_AIOnRemove(mobj_t *mo);

boolean CR_AIHandlesActor(const mobj_t *actor);

// Action entry: A_CRKPAThink delegates here. Registers on demand.
void CR_AIThink(mobj_t *actor);
// Action entry for the attack frame: one rifle hitscan.
void CR_AIFire(mobj_t *actor);
// Noise consumers: called by CR_EmitNoise with the captured event.
void CR_AIDispatchNoise(const cr_noise_event_t *event);

// Instrumentation and HUD helpers.
int CR_AIAliveCount(void);
int CR_AICombatCount(void);
int CR_AIRegisteredCount(void);
const char *CR_AIStateName(cr_ai_state_t state);
cr_ai_state_t CR_AIStateOf(const mobj_t *actor);
int CR_AISuspicionOf(const mobj_t *actor);

#endif
