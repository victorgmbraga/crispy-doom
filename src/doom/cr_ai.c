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
// Crysis soldier perception and behavior. The registry owns the decision
// state; vanilla movement primitives are reused for locomotion.
//

#include <stdio.h>
#include <string.h>

#include "doomdef.h"
#include "doomstat.h"
#include "m_random.h"
#include "p_local.h"
#include "r_main.h"
#include "s_sound.h"
#include "tables.h"

#include "cr_ai.h"
#include "cr_defs.h"
#include "cr_game.h"
#include "cr_nanosuit.h"
#include "cr_sound.h"
#include "sounds.h"

// p_enemy.c keeps these local; only the locomotion primitives are reused.
boolean P_Move(mobj_t *actor);
boolean P_TryWalk(mobj_t *actor);
void P_NewChaseDir(mobj_t *actor);

#define CR_AI_NODIR 8

// Perception and behavior tuning (initial, subject to playtest).
#define CR_AI_SIGHT_MAX_DIST        (1100 * FRACUNIT)
#define CR_AI_SIGHT_GAIN            (32 * FRACUNIT)
#define CR_AI_SUSPICION_DECAY       (3 * FRACUNIT)
#define CR_AI_SUSPICIOUS_LEVEL      (25 * FRACUNIT)
#define CR_AI_INVESTIGATE_LEVEL     (50 * FRACUNIT)
#define CR_AI_COMBAT_LEVEL          (100 * FRACUNIT)
#define CR_AI_NOISE_GAIN            (40 * FRACUNIT)
#define CR_AI_NOISE_GAIN_SUPPRESSED (15 * FRACUNIT)
#define CR_AI_ALERT_TICS            12
#define CR_AI_SUSPICIOUS_TICS       52
#define CR_AI_COMBAT_MEMORY_TICS    70
#define CR_AI_SEARCH_TICS           105
#define CR_AI_ARRIVE_DIST           (48 * FRACUNIT)
#define CR_AI_KPA_DAMAGE            8
#define CR_AI_BURST_SHOTS           3
#define CR_AI_BURST_COOLDOWN        35

typedef struct
{
    mobj_t *actor;
    cr_ai_state_t state;
    fixed_t suspicion;
    int last_seen_tic;
    fixed_t last_seen_x, last_seen_y;
    int last_heard_tic;
    fixed_t last_heard_x, last_heard_y;
    int state_tic;
    int next_think_tic;
    int next_attack_tic;
    fixed_t home_x, home_y;
    int los_checks;
} cr_ai_actor_t;

static cr_ai_actor_t cr_ai_actors[CR_AI_MAX_ACTORS];
static int cr_ai_los_checks;

static const char *const cr_ai_state_names[] =
{
    "PATROL",
    "SUSPICIOUS",
    "INVESTIGATE",
    "ALERT",
    "COMBAT",
    "SEARCH",
    "RETURN"
};

const char *CR_AIStateName(cr_ai_state_t state)
{
    if (state < 0 || state > CR_AI_RETURN)
    {
        return "?";
    }

    return cr_ai_state_names[state];
}

static cr_ai_actor_t *FindActor(const mobj_t *actor)
{
    int i;

    for (i = 0; i < CR_AI_MAX_ACTORS; ++i)
    {
        if (cr_ai_actors[i].actor == actor)
        {
            return &cr_ai_actors[i];
        }
    }

    return NULL;
}

static cr_ai_actor_t *RegisterActor(mobj_t *actor)
{
    int i;

    if (actor == NULL || FindActor(actor) != NULL)
    {
        return FindActor(actor);
    }

    for (i = 0; i < CR_AI_MAX_ACTORS; ++i)
    {
        if (cr_ai_actors[i].actor == NULL)
        {
            memset(&cr_ai_actors[i], 0, sizeof(cr_ai_actors[i]));
            cr_ai_actors[i].actor = actor;
            cr_ai_actors[i].state = CR_AI_PATROL;
            cr_ai_actors[i].suspicion = 0;
            cr_ai_actors[i].last_seen_tic = -1;
            cr_ai_actors[i].last_heard_tic = -1;
            cr_ai_actors[i].state_tic = leveltime;
            cr_ai_actors[i].next_think_tic = leveltime;
            cr_ai_actors[i].home_x = actor->x;
            cr_ai_actors[i].home_y = actor->y;
            return &cr_ai_actors[i];
        }
    }

    if (CR_DebugEnabled())
    {
        printf(CR_LOG_PREFIX " ai registry full, actor ignored\n");
    }

    return NULL;
}

void CR_AIReset(void)
{
    memset(cr_ai_actors, 0, sizeof(cr_ai_actors));
    cr_ai_los_checks = 0;
}

void CR_AILevelEnd(void)
{
    memset(cr_ai_actors, 0, sizeof(cr_ai_actors));
}

boolean CR_AIHandlesActor(const mobj_t *actor)
{
    return actor != NULL && actor->type == MT_CR_KPA;
}

void CR_AIOnSpawn(mobj_t *mo)
{
    if (!CR_IsActive() || !CR_AIHandlesActor(mo))
    {
        return;
    }

    RegisterActor(mo);
}

void CR_AIOnRemove(mobj_t *mo)
{
    cr_ai_actor_t *entry = FindActor(mo);

    if (entry != NULL)
    {
        memset(entry, 0, sizeof(*entry));
    }
}

int CR_AIRegisteredCount(void)
{
    int i;
    int count = 0;

    for (i = 0; i < CR_AI_MAX_ACTORS; ++i)
    {
        if (cr_ai_actors[i].actor != NULL)
        {
            ++count;
        }
    }

    return count;
}

int CR_AIAliveCount(void)
{
    int i;
    int count = 0;

    for (i = 0; i < CR_AI_MAX_ACTORS; ++i)
    {
        if (cr_ai_actors[i].actor != NULL
            && cr_ai_actors[i].actor->health > 0)
        {
            ++count;
        }
    }

    return count;
}

int CR_AICombatCount(void)
{
    int i;
    int count = 0;

    for (i = 0; i < CR_AI_MAX_ACTORS; ++i)
    {
        if (cr_ai_actors[i].actor != NULL
            && cr_ai_actors[i].actor->health > 0
            && cr_ai_actors[i].state == CR_AI_COMBAT)
        {
            ++count;
        }
    }

    return count;
}

cr_ai_state_t CR_AIStateOf(const mobj_t *actor)
{
    const cr_ai_actor_t *entry = FindActor(actor);

    return entry == NULL ? CR_AI_PATROL : entry->state;
}

int CR_AISuspicionOf(const mobj_t *actor)
{
    const cr_ai_actor_t *entry = FindActor(actor);

    return entry == NULL ? 0 : (int) (entry->suspicion >> FRACBITS);
}

static player_t *LivePlayer(void)
{
    int i;

    for (i = 0; i < MAXPLAYERS; ++i)
    {
        if (playeringame[i] && players[i].playerstate == PST_LIVE
            && players[i].mo != NULL && players[i].health > 0)
        {
            return &players[i];
        }
    }

    return NULL;
}

static void SetAIState(cr_ai_actor_t *entry, cr_ai_state_t state)
{
    if (entry->state == state)
    {
        return;
    }

    entry->state = state;
    entry->state_tic = leveltime;

    if (CR_DebugEnabled())
    {
        printf(CR_LOG_PREFIX " ai state=%s suspicion=%d tic=%d\n",
               CR_AIStateName(state), (int) (entry->suspicion >> FRACBITS),
               leveltime);
    }
}

static void AddSuspicion(cr_ai_actor_t *entry, fixed_t amount)
{
    entry->suspicion += amount;

    if (entry->suspicion > CR_AI_COMBAT_LEVEL * 2)
    {
        entry->suspicion = CR_AI_COMBAT_LEVEL * 2;
    }

    if (entry->suspicion < 0)
    {
        entry->suspicion = 0;
    }
}

static void FacePoint(mobj_t *actor, fixed_t x, fixed_t y)
{
    actor->angle = R_PointToAngle2(actor->x, actor->y, x, y);
}

static boolean ArrivedAt(mobj_t *actor, fixed_t x, fixed_t y)
{
    return P_AproxDistance(actor->x - x, actor->y - y) <= CR_AI_ARRIVE_DIST;
}

// Last seen position wins; otherwise the last heard position.
static boolean LastKnownPoint(const cr_ai_actor_t *entry, fixed_t *x,
                              fixed_t *y)
{
    if (entry->last_seen_tic >= 0)
    {
        *x = entry->last_seen_x;
        *y = entry->last_seen_y;
        return true;
    }

    if (entry->last_heard_tic >= 0)
    {
        *x = entry->last_heard_x;
        *y = entry->last_heard_y;
        return true;
    }

    return false;
}

// Simplified chase step using the vanilla movement primitives.
static void ChaseStep(mobj_t *actor)
{
    if (actor->movedir != CR_AI_NODIR)
    {
        angle_t delta = actor->angle - (actor->movedir << 29);

        if (delta > 0)
        {
            actor->angle -= ANG90 / 2;
        }
        else if (delta < 0)
        {
            actor->angle += ANG90 / 2;
        }
    }

    if (P_Move(actor))
    {
        return;
    }

    actor->movedir = CR_AI_NODIR;
    P_NewChaseDir(actor);
}

static void MoveToward(mobj_t *actor, fixed_t x, fixed_t y)
{
    if (!ArrivedAt(actor, x, y))
    {
        FacePoint(actor, x, y);
    }

    ChaseStep(actor);
}

static void VisualCheck(cr_ai_actor_t *entry, mobj_t *actor, player_t *player)
{
    mobj_t *pm = player->mo;
    fixed_t dx;
    fixed_t dy;
    fixed_t dist;
    angle_t diff;
    boolean incone;
    boolean alerted;

    if (pm == NULL)
    {
        return;
    }

    dx = pm->x - actor->x;
    dy = pm->y - actor->y;
    dist = P_AproxDistance(dx, dy);

    diff = R_PointToAngle2(actor->x, actor->y, pm->x, pm->y) - actor->angle;
    if (diff > ANG180)
    {
        diff = (angle_t) -diff;
    }

    alerted = entry->state == CR_AI_COMBAT || entry->state == CR_AI_ALERT;
    incone = diff < (alerted ? ANG90 : ANG90 / 2);

    ++entry->los_checks;
    ++cr_ai_los_checks;

    if (dist < CR_AI_SIGHT_MAX_DIST && incone && P_CheckSight(actor, pm))
    {
        fixed_t falloff = FixedDiv(CR_AI_SIGHT_MAX_DIST - dist,
                                   CR_AI_SIGHT_MAX_DIST);
        fixed_t gain = FixedMul(CR_AI_SIGHT_GAIN,
                                CR_SuitVisibilityFactor(player));

        gain = FixedMul(gain, falloff);

        if (player->cmd.forwardmove || player->cmd.sidemove)
        {
            gain += gain / 2;
        }

        AddSuspicion(entry, gain);
        entry->last_seen_x = pm->x;
        entry->last_seen_y = pm->y;
        entry->last_seen_tic = leveltime;

        // The target is assigned only after a valid sighting.
        actor->target = pm;
    }
    else if (!alerted)
    {
        AddSuspicion(entry, -CR_AI_SUSPICION_DECAY);
    }
}

void CR_AIThink(mobj_t *actor)
{
    cr_ai_actor_t *entry;
    player_t *player;
    mobj_t *pm;

    if (!CR_IsActive() || !CR_AIHandlesActor(actor) || actor->health <= 0)
    {
        return;
    }

    entry = FindActor(actor);

    if (entry == NULL)
    {
        entry = RegisterActor(actor);

        if (entry == NULL)
        {
            return;
        }
    }

    player = LivePlayer();

    if (player == NULL)
    {
        return;
    }

    pm = player->mo;

    if (leveltime >= entry->next_think_tic)
    {
        VisualCheck(entry, actor, player);
        entry->next_think_tic = leveltime
            + ((entry->state == CR_AI_COMBAT || entry->state == CR_AI_ALERT)
               ? 2 : 4);
    }

    // Global escalation: confirmed visual contact goes through a reaction.
    if (entry->suspicion >= CR_AI_COMBAT_LEVEL
        && entry->state != CR_AI_COMBAT && entry->state != CR_AI_ALERT)
    {
        SetAIState(entry, CR_AI_ALERT);
    }
    else if (entry->state == CR_AI_PATROL
             && entry->suspicion >= CR_AI_INVESTIGATE_LEVEL)
    {
        SetAIState(entry, CR_AI_INVESTIGATE);
    }
    else if (entry->state == CR_AI_PATROL
             && entry->suspicion >= CR_AI_SUSPICIOUS_LEVEL)
    {
        SetAIState(entry, CR_AI_SUSPICIOUS);
    }

    switch (entry->state)
    {
        case CR_AI_PATROL:
        {
            break;
        }

        case CR_AI_SUSPICIOUS:
        {
            if (entry->last_seen_tic >= 0)
            {
                FacePoint(actor, entry->last_seen_x, entry->last_seen_y);
            }
            else if (entry->last_heard_tic >= 0)
            {
                FacePoint(actor, entry->last_heard_x, entry->last_heard_y);
            }

            if (leveltime - entry->state_tic > CR_AI_SUSPICIOUS_TICS)
            {
                if (entry->last_heard_tic >= 0
                    && leveltime - entry->last_heard_tic
                       < CR_AI_SUSPICIOUS_TICS * 2)
                {
                    SetAIState(entry, CR_AI_INVESTIGATE);
                }
                else
                {
                    SetAIState(entry, CR_AI_PATROL);
                }
            }
            break;
        }

        case CR_AI_INVESTIGATE:
        {
            fixed_t gx;
            fixed_t gy;

            if (!LastKnownPoint(entry, &gx, &gy))
            {
                SetAIState(entry, CR_AI_RETURN);
                break;
            }

            MoveToward(actor, gx, gy);

            if (ArrivedAt(actor, gx, gy))
            {
                SetAIState(entry, CR_AI_SEARCH);
            }
            else if (leveltime - entry->state_tic > CR_AI_SEARCH_TICS * 2)
            {
                SetAIState(entry, CR_AI_RETURN);
            }
            break;
        }

        case CR_AI_ALERT:
        {
            if (entry->last_seen_tic >= 0)
            {
                FacePoint(actor, entry->last_seen_x, entry->last_seen_y);
            }
            else if (entry->last_heard_tic >= 0)
            {
                FacePoint(actor, entry->last_heard_x, entry->last_heard_y);
            }

            if (leveltime - entry->state_tic >= CR_AI_ALERT_TICS)
            {
                if (entry->last_seen_tic >= 0
                    && leveltime - entry->last_seen_tic
                       <= CR_AI_COMBAT_MEMORY_TICS)
                {
                    SetAIState(entry, CR_AI_COMBAT);
                }
                else
                {
                    SetAIState(entry, CR_AI_SEARCH);
                }
            }
            break;
        }

        case CR_AI_COMBAT:
        {
            boolean recent = entry->last_seen_tic >= 0
                && leveltime - entry->last_seen_tic
                   <= CR_AI_COMBAT_MEMORY_TICS;
            fixed_t dist;

            if (!recent || pm == NULL)
            {
                SetAIState(entry, CR_AI_SEARCH);
                break;
            }

            FacePoint(actor, entry->last_seen_x, entry->last_seen_y);

            dist = P_AproxDistance(pm->x - actor->x, pm->y - actor->y);

            if (dist > 420 * FRACUNIT)
            {
                MoveToward(actor, entry->last_seen_x, entry->last_seen_y);
            }

            if (P_CheckSight(actor, pm) && leveltime >= entry->next_attack_tic)
            {
                P_SetMobjState(actor, S_CR_KPA_ATK1);
            }
            break;
        }

        case CR_AI_SEARCH:
        {
            fixed_t gx;
            fixed_t gy;
            boolean havePoint;
            boolean recent = entry->last_seen_tic >= 0
                && leveltime - entry->last_seen_tic
                   <= CR_AI_COMBAT_MEMORY_TICS;

            if (recent)
            {
                SetAIState(entry, CR_AI_COMBAT);
                break;
            }

            havePoint = LastKnownPoint(entry, &gx, &gy);

            if (!havePoint)
            {
                SetAIState(entry, CR_AI_RETURN);
                break;
            }

            MoveToward(actor, gx, gy);

            // Sweep the view while searching.
            if ((leveltime - entry->state_tic) % 18 == 0)
            {
                actor->angle += ANG45;
            }

            if (ArrivedAt(actor, gx, gy)
                && leveltime - entry->state_tic > CR_AI_SEARCH_TICS)
            {
                SetAIState(entry, CR_AI_RETURN);
            }
            break;
        }

        case CR_AI_RETURN:
        {
            MoveToward(actor, entry->home_x, entry->home_y);

            if (ArrivedAt(actor, entry->home_x, entry->home_y))
            {
                entry->suspicion = 0;
                actor->target = NULL;
                SetAIState(entry, CR_AI_PATROL);
            }
            break;
        }
    }
}

void CR_AIFire(mobj_t *actor)
{
    cr_ai_actor_t *entry;
    player_t *player;
    mobj_t *pm;
    fixed_t dist;
    int spread;
    int i;

    if (!CR_IsActive() || !CR_AIHandlesActor(actor) || actor->health <= 0)
    {
        return;
    }

    player = LivePlayer();

    if (player == NULL || player->mo == NULL)
    {
        return;
    }

    pm = player->mo;

    if (!P_CheckSight(actor, pm))
    {
        return;
    }

    entry = FindActor(actor);

    if (entry != NULL && leveltime < entry->next_attack_tic)
    {
        return;
    }

    dist = P_AproxDistance(pm->x - actor->x, pm->y - actor->y);
    spread = dist > 512 * FRACUNIT ? 32
             : (dist > 256 * FRACUNIT ? 16 : 8);

    for (i = 0; i < CR_AI_BURST_SHOTS; ++i)
    {
        angle_t angle = R_PointToAngle2(actor->x, actor->y, pm->x, pm->y);
        fixed_t slope;

        angle += P_SubRandom() * spread;
        slope = P_AimLineAttack(actor, angle, MISSILERANGE);
        P_LineAttack(actor, angle, MISSILERANGE, slope, CR_AI_KPA_DAMAGE);
    }

    S_StartSound(actor, sfx_pistol);
    CR_EmitNoise(actor, actor->x, actor->y, 900 * FRACUNIT,
                 CR_NOISE_GUNSHOT);

    if (entry != NULL)
    {
        entry->next_attack_tic = leveltime + CR_AI_BURST_COOLDOWN;
    }
}

void CR_AIDispatchNoise(const cr_noise_event_t *event)
{
    int i;

    if (!CR_IsActive() || event == NULL || event->radius <= 0)
    {
        return;
    }

    for (i = 0; i < CR_AI_MAX_ACTORS; ++i)
    {
        cr_ai_actor_t *entry = &cr_ai_actors[i];
        mobj_t *actor = entry->actor;
        fixed_t dist;
        fixed_t gain;

        if (actor == NULL || actor->health <= 0)
        {
            continue;
        }

        dist = P_AproxDistance(actor->x - event->x, actor->y - event->y);

        if (dist > event->radius)
        {
            continue;
        }

        gain = (event->type == CR_NOISE_SUPPRESSED_GUNSHOT)
               ? CR_AI_NOISE_GAIN_SUPPRESSED : CR_AI_NOISE_GAIN;
        gain = FixedMul(gain, FixedDiv(event->radius - dist, event->radius));

        AddSuspicion(entry, gain);
        entry->last_heard_x = event->x;
        entry->last_heard_y = event->y;
        entry->last_heard_tic = leveltime;

        if (entry->state == CR_AI_PATROL
            || entry->state == CR_AI_SUSPICIOUS
            || entry->state == CR_AI_RETURN)
        {
            SetAIState(entry, CR_AI_INVESTIGATE);
        }
        else if (entry->state == CR_AI_SEARCH
                 && leveltime - entry->state_tic > 30)
        {
            SetAIState(entry, CR_AI_INVESTIGATE);
        }
    }
}

// [crysis] Action pointers used by the KPA state table (see info.c).
void A_CRKPAThink(mobj_t *actor)
{
    CR_AIThink(actor);
}

void A_CRKPAFire(mobj_t *actor)
{
    CR_AIFire(actor);
}
