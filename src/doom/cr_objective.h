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
// Mission objectives: stable IDs, a fixed main graph and idempotent
// transitions. No engine state is touched here.
//

#ifndef CR_OBJECTIVE_H
#define CR_OBJECTIVE_H

#include "doomdef.h"

typedef enum
{
    CR_OBJ_LOCKED = 0,
    CR_OBJ_ACTIVE,
    CR_OBJ_COMPLETE,
    CR_OBJ_FAILED
} cr_objective_state_t;

typedef struct
{
    int id;
    const char *title;
    boolean optional;
    cr_objective_state_t state;
} cr_objective_t;

// Reserved mission IDs for the vertical slice.
#define CR_OBJECTIVE_MEETING 1
#define CR_OBJECTIVE_PATROL  2
#define CR_OBJECTIVE_JAMMER  3
#define CR_OBJECTIVE_EXIT    4

void CR_ObjectivesReset(void);

// LOCKED -> ACTIVE -> COMPLETE; later calls on COMPLETE are no-ops.
boolean CR_ObjectiveTrigger(int id);
void CR_ObjectiveActivate(int id);
void CR_ObjectiveComplete(int id);
void CR_ObjectiveFail(int id);

cr_objective_state_t CR_ObjectiveState(int id);
const cr_objective_t *CR_ObjectiveById(int id);
// First actionable main objective: ACTIVE wins over the next LOCKED one.
const cr_objective_t *CR_ObjectiveCurrent(void);

int CR_ObjectiveCount(void);
const cr_objective_t *CR_ObjectiveAt(int index);

// True when every main objective except the exit is complete.
boolean CR_ObjectiveCanExit(void);

#endif
