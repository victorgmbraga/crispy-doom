// Copyright(C) 2026 Crysis Contact Demake contributors
// SPDX-License-Identifier: GPL-2.0-or-later

#ifndef CR_PLAYER_H
#define CR_PLAYER_H

#include "doomdef.h"
#include "d_player.h"
#include "cr_nanosuit.h"

typedef struct
{
    boolean initialized;
    byte buttons_down;
    byte buttons_pressed;
    byte buttons_released;
    boolean sprinting;
    boolean ads;
    boolean crouching; // Request only: F1 does not change stance/collision.

    // Health regeneration (Phase 3); damage notes arrive from the suit hook.
    int last_damage_tic;
    int health_regen_accumulator;

    cr_nanosuit_t suit;
} cr_player_state_t;

extern cr_player_state_t cr_players[MAXPLAYERS];

cr_player_state_t *CR_PlayerState(player_t *player);
const cr_player_state_t *CR_PlayerStateConst(const player_t *player);
void CR_PlayerReset(player_t *player);
void CR_PlayerClearCommands(void);
void CR_PlayerThink(player_t *player);

// Called once per damaging hit on a live player.
void CR_PlayerNoteDamage(player_t *player);

#endif
