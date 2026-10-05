// Copyright(C) 2026 Crysis Contact Demake contributors
// SPDX-License-Identifier: GPL-2.0-or-later

#ifndef CR_PLAYER_H
#define CR_PLAYER_H

#include "doomdef.h"
#include "d_player.h"

// Input state only in F1; suit/weapon state belongs to subsequent phases.
typedef struct
{
    boolean initialized;
    byte buttons_down;
    byte buttons_pressed;
    byte buttons_released;
    boolean sprinting;
    boolean ads;
    boolean crouching; // Request only: F1 does not change stance/collision.
} cr_player_state_t;

extern cr_player_state_t cr_players[MAXPLAYERS];

cr_player_state_t *CR_PlayerState(player_t *player);
const cr_player_state_t *CR_PlayerStateConst(const player_t *player);
void CR_PlayerReset(player_t *player);
void CR_PlayerClearCommands(void);
void CR_PlayerThink(player_t *player);

#endif
