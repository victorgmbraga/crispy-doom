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
// Nanosuit modes, energy and their gameplay modifiers.
//

#ifndef CR_NANOSUIT_H
#define CR_NANOSUIT_H

#include "doomdef.h"
#include "d_player.h"
#include "m_fixed.h"

typedef enum
{
    CR_SUIT_ARMOR = 0,
    CR_SUIT_STRENGTH,
    CR_SUIT_SPEED,
    CR_SUIT_CLOAK,
    CR_SUIT_COUNT
} cr_suit_mode_t;

typedef struct
{
    cr_suit_mode_t mode;
    int energy;
    int max_energy;
    int recharge_delay_tics;
    int recharge_block_until;
    boolean cloak_visible;
    // Drain tick counters; one energy per period as an exact rate.
    int cloak_drain_accum;
    int speed_drain_accum;
} cr_nanosuit_t;

// All balance numbers live here.
#define CR_SUIT_MAX_ENERGY              100
#define CR_SUIT_RECHARGE_DELAY_TICS      35
#define CR_SUIT_RECHARGE_PER_TIC          1
#define CR_CLOAK_IDLE_DRAIN_TICS          8
#define CR_CLOAK_MOVE_DRAIN_TICS          3
#define CR_CLOAK_RUN_DRAIN_TICS           2
#define CR_SPEED_SPRINT_DRAIN_TICS        3
#define CR_ARMOR_DAMAGE_ENERGY_NUM        1
#define CR_ARMOR_DAMAGE_ENERGY_DEN        1

// Movement and match multiples, applied as fixed-point factors.
#define CR_MOVE_SPRINT                  (2 * FRACUNIT)
#define CR_MOVE_SPEED        (13 * FRACUNIT / 5) // Sprint + Speed mode.
#define CR_MOVE_ADS                     (FRACUNIT / 2)
#define CR_STRENGTH_JUMP_FACTOR (3 * FRACUNIT / 2)
#define CR_STRENGTH_MELEE_FACTOR        (2 * FRACUNIT)
#define CR_STRENGTH_JUMP_COST             10
#define CR_STRENGTH_MELEE_COST             5

// Visibility factors for the AI perception (Phase 6).
#define CR_CLOAK_VIS_IDLE       (5 * FRACUNIT / 100)
#define CR_CLOAK_VIS_MOVE      (15 * FRACUNIT / 100)
#define CR_CLOAK_VIS_RUN       (35 * FRACUNIT / 100)

void CR_SuitInit(cr_nanosuit_t *suit);
void CR_SuitTick(player_t *player);
void CR_SuitSetMode(player_t *player, cr_suit_mode_t mode);
void CR_SuitNextMode(player_t *player);
int CR_SuitAbsorbDamage(player_t *player, int damage);
void CR_SuitOnWeaponFired(player_t *player);
boolean CR_SuitConsume(player_t *player, int amount);

// Perception hook: 0..FRACUNIT multiplier for visual detection.
fixed_t CR_SuitVisibilityFactor(const player_t *player);

// Movement hooks used by the vanilla call sites.
fixed_t CR_SuitMoveFactor(const player_t *player);
fixed_t CR_SuitJumpMomentum(const player_t *player, fixed_t normal_momz);
int CR_SuitMeleeDamage(player_t *player, int base_damage);
fixed_t CR_SuitRecoilScale(const player_t *player);

// Shared state queries for other Crysis modules.
boolean CR_SuitIsMode(const player_t *player, cr_suit_mode_t mode);
boolean CR_SuitSprintBlocked(const player_t *player);
const char *CR_SuitModeName(cr_suit_mode_t mode);

#endif
