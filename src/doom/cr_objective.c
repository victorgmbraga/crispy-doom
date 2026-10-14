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
// Mission objectives. One owner of the objective table; callers only
// request transitions.
//

#include <string.h>

#include "doomdef.h"

#include "cr_objective.h"

static cr_objective_t cr_objectives[] =
{
    { CR_OBJECTIVE_MEETING, "REACH THE MEETING POINT", false, CR_OBJ_LOCKED },
    { CR_OBJECTIVE_PATROL,  "CROSS THE PATROL AREA",   false, CR_OBJ_LOCKED },
    { CR_OBJECTIVE_JAMMER,  "DISABLE THE JAMMER",      true,  CR_OBJ_LOCKED },
    { CR_OBJECTIVE_EXIT,    "LEAVE THE AREA",          false, CR_OBJ_LOCKED }
};

#define CR_OBJECTIVE_TABLE_SIZE \
    ((int) (sizeof(cr_objectives) / sizeof(cr_objectives[0])))

int CR_ObjectiveCount(void)
{
    return CR_OBJECTIVE_TABLE_SIZE;
}

const cr_objective_t *CR_ObjectiveAt(int index)
{
    if (index < 0 || index >= CR_OBJECTIVE_TABLE_SIZE)
    {
        return NULL;
    }

    return &cr_objectives[index];
}

const cr_objective_t *CR_ObjectiveById(int id)
{
    int i;

    for (i = 0; i < CR_OBJECTIVE_TABLE_SIZE; ++i)
    {
        if (cr_objectives[i].id == id)
        {
            return &cr_objectives[i];
        }
    }

    return NULL;
}

void CR_ObjectivesReset(void)
{
    int i;

    for (i = 0; i < CR_OBJECTIVE_TABLE_SIZE; ++i)
    {
        cr_objectives[i].state = CR_OBJ_LOCKED;
    }
}

void CR_ObjectiveActivate(int id)
{
    cr_objective_t *objective = (cr_objective_t *) CR_ObjectiveById(id);

    // Explicit activation also revives a failed objective.
    if (objective != NULL
        && (objective->state == CR_OBJ_LOCKED
            || objective->state == CR_OBJ_FAILED))
    {
        objective->state = CR_OBJ_ACTIVE;
    }
}

void CR_ObjectiveComplete(int id)
{
    cr_objective_t *objective = (cr_objective_t *) CR_ObjectiveById(id);

    if (objective != NULL && objective->state != CR_OBJ_COMPLETE)
    {
        objective->state = CR_OBJ_COMPLETE;
    }
}

void CR_ObjectiveFail(int id)
{
    cr_objective_t *objective = (cr_objective_t *) CR_ObjectiveById(id);

    if (objective != NULL && objective->state == CR_OBJ_ACTIVE)
    {
        objective->state = CR_OBJ_FAILED;
    }
}

boolean CR_ObjectiveTrigger(int id)
{
    cr_objective_t *objective = (cr_objective_t *) CR_ObjectiveById(id);

    if (objective == NULL)
    {
        return false;
    }

    switch (objective->state)
    {
        case CR_OBJ_LOCKED:
            objective->state = CR_OBJ_ACTIVE;
            return true;

        case CR_OBJ_ACTIVE:
            objective->state = CR_OBJ_COMPLETE;
            return true;

        default:
            // Repeated events never reopen a completed objective.
            return false;
    }
}

cr_objective_state_t CR_ObjectiveState(int id)
{
    const cr_objective_t *objective = CR_ObjectiveById(id);

    return objective == NULL ? CR_OBJ_FAILED : objective->state;
}

const cr_objective_t *CR_ObjectiveCurrent(void)
{
    int i;

    for (i = 0; i < CR_OBJECTIVE_TABLE_SIZE; ++i)
    {
        if (!cr_objectives[i].optional
            && cr_objectives[i].state == CR_OBJ_ACTIVE)
        {
            return &cr_objectives[i];
        }
    }

    for (i = 0; i < CR_OBJECTIVE_TABLE_SIZE; ++i)
    {
        if (!cr_objectives[i].optional
            && cr_objectives[i].state == CR_OBJ_LOCKED)
        {
            return &cr_objectives[i];
        }
    }

    return NULL;
}

boolean CR_ObjectiveCanExit(void)
{
    int i;

    for (i = 0; i < CR_OBJECTIVE_TABLE_SIZE; ++i)
    {
        if (!cr_objectives[i].optional
            && cr_objectives[i].id != CR_OBJECTIVE_EXIT
            && cr_objectives[i].state != CR_OBJ_COMPLETE)
        {
            return false;
        }
    }

    return true;
}
