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
// Nanosuit modes, energy, absorption and modifiers. Single owner of the
// suit state; every consumer reads through the API in cr_nanosuit.h.
//

#include <stdio.h>
#include <string.h>

#include "doomdef.h"
#include "doomstat.h"
#include "m_fixed.h"

#include "cr_defs.h"
#include "cr_game.h"
#include "cr_nanosuit.h"
#include "cr_player.h"

static const char *const suit_mode_names[CR_SUIT_COUNT] =
{
    "ARMOR",
    "STRENGTH",
    "SPEED",
    "CLOAK"
};

static cr_nanosuit_t *SuitForPlayer(const player_t *player)
{
    cr_player_state_t *state = CR_PlayerState((player_t *) player);

    return state == NULL ? NULL : &state->suit;
}

void CR_SuitInit(cr_nanosuit_t *suit)
{
    if (suit == NULL)
    {
        return;
    }

    memset(suit, 0, sizeof(*suit));
    suit->mode = CR_SUIT_ARMOR;
    suit->max_energy = CR_SUIT_MAX_ENERGY;
    suit->energy = suit->max_energy;
    suit->recharge_delay_tics = CR_SUIT_RECHARGE_DELAY_TICS;
}

const char *CR_SuitModeName(cr_suit_mode_t mode)
{
    if (mode < 0 || mode >= CR_SUIT_COUNT)
    {
        return "?";
    }

    return suit_mode_names[mode];
}

boolean CR_SuitIsMode(const player_t *player, cr_suit_mode_t mode)
{
    const cr_nanosuit_t *suit = SuitForPlayer(player);

    return suit != NULL && suit->mode == mode;
}

// One-shot commands must not be blocked once the energy is gone, or the
// suit could never be switched after depletion.
boolean CR_SuitSprintBlocked(const player_t *player)
{
    const cr_nanosuit_t *suit = SuitForPlayer(player);

    if (suit == NULL)
    {
        return false;
    }

    // Sprint costs nothing outside Speed mode, so only Speed is gated.
    return suit->mode == CR_SUIT_SPEED && suit->energy <= 0;
}

void CR_SuitSetMode(player_t *player, cr_suit_mode_t mode)
{
    cr_nanosuit_t *suit = SuitForPlayer(player);

    if (suit == NULL || mode < 0 || mode >= CR_SUIT_COUNT)
    {
        return;
    }

    if (suit->mode == mode)
    {
        return;
    }

    suit->mode = mode;
    suit->cloak_drain_accum = 0;
    suit->speed_drain_accum = 0;

    if (CR_DebugEnabled())
    {
        printf(CR_LOG_PREFIX " suit mode=%s energy=%d\n",
               CR_SuitModeName(mode), suit->energy);
    }
}

void CR_SuitNextMode(player_t *player)
{
    cr_nanosuit_t *suit = SuitForPlayer(player);

    if (suit == NULL)
    {
        return;
    }

    CR_SuitSetMode(player, (suit->mode + 1) % CR_SUIT_COUNT);
}

boolean CR_SuitConsume(player_t *player, int amount)
{
    cr_nanosuit_t *suit = SuitForPlayer(player);

    if (!CR_IsActive() || suit == NULL || amount <= 0
        || suit->energy < amount)
    {
        return false;
    }

    suit->energy -= amount;

    if (suit->energy <= 0)
    {
        suit->energy = 0;

        // Energy zero ends active modes; armor remains but has no charge.
        suit->mode = CR_SUIT_ARMOR;
        suit->cloak_drain_accum = 0;
        suit->speed_drain_accum = 0;
        // Depletion also starts the recharge delay.
        suit->recharge_block_until = leveltime + suit->recharge_delay_tics;
    }

    return true;
}

// Drain 1 energy per "period" tics without truncation artifacts.
static boolean DrainRate(cr_nanosuit_t *suit, int *accum, int period)
{
    ++*accum;

    if (*accum >= period)
    {
        *accum = 0;

        if (suit->energy > 0)
        {
            suit->energy--;
        }
    }

    if (suit->energy <= 0)
    {
        suit->energy = 0;
        suit->mode = CR_SUIT_ARMOR;
        *accum = 0;
        // Depletion also starts the recharge delay.
        suit->recharge_block_until = leveltime + suit->recharge_delay_tics;
        return false;
    }

    return true;
}

static boolean PlayerMoving(const player_t *player)
{
    return player->cmd.forwardmove != 0 || player->cmd.sidemove != 0;
}

void CR_SuitTick(player_t *player)
{
    cr_player_state_t *state;
    cr_nanosuit_t *suit;
    boolean drained = false;

    state = CR_PlayerState(player);

    if (state == NULL)
    {
        return;
    }

    suit = &state->suit;

    if (player->playerstate != PST_LIVE)
    {
        // Death clears transient states; nothing ticks while dead.
        suit->cloak_drain_accum = 0;
        suit->speed_drain_accum = 0;
        return;
    }

    // Q edge: cycle modes. The edge was computed by CR_PlayerThink.
    if (state->buttons_pressed & CR_BT2_SUIT_NEXT)
    {
        CR_SuitNextMode(player);
    }

    switch (suit->mode)
    {
        case CR_SUIT_CLOAK:
        {
            int period = CR_CLOAK_IDLE_DRAIN_TICS;

            if (PlayerMoving(player))
            {
                period = state->sprinting ? CR_CLOAK_RUN_DRAIN_TICS
                                          : CR_CLOAK_MOVE_DRAIN_TICS;
            }

            drained = DrainRate(suit, &suit->cloak_drain_accum, period);
            break;
        }

        case CR_SUIT_SPEED:
        {
            if (state->sprinting && !state->ads && PlayerMoving(player))
            {
                drained = DrainRate(suit, &suit->speed_drain_accum,
                                    CR_SPEED_SPRINT_DRAIN_TICS);
            }
            else
            {
                suit->speed_drain_accum = 0;
            }
            break;
        }

        default:
        {
            suit->cloak_drain_accum = 0;
            suit->speed_drain_accum = 0;
            break;
        }
    }

    // Recharge only after the delay and while nothing drains.
    if (!drained && suit->energy < suit->max_energy
        && leveltime >= suit->recharge_block_until)
    {
        suit->energy += CR_SUIT_RECHARGE_PER_TIC;

        if (suit->energy > suit->max_energy)
        {
            suit->energy = suit->max_energy;
        }
    }

    // A revealed cloak becomes usable again once the battery is back.
    if (suit->cloak_visible && suit->energy >= suit->max_energy / 4)
    {
        suit->cloak_visible = false;
    }
}

int CR_SuitAbsorbDamage(player_t *player, int damage)
{
    cr_nanosuit_t *suit = SuitForPlayer(player);
    int needed;
    int absorbed;

    if (!CR_IsActive() || suit == NULL || damage <= 0)
    {
        return damage;
    }

    // Any damage restarts both delays, even if fully absorbed.
    suit->recharge_block_until = leveltime + suit->recharge_delay_tics;
    CR_PlayerNoteDamage(player);

    if (suit->mode != CR_SUIT_ARMOR || suit->energy <= 0)
    {
        return damage;
    }

    needed = (damage * CR_ARMOR_DAMAGE_ENERGY_NUM
              + CR_ARMOR_DAMAGE_ENERGY_DEN - 1) / CR_ARMOR_DAMAGE_ENERGY_DEN;

    if (needed <= suit->energy)
    {
        suit->energy -= needed;
        return 0;
    }

    // Not enough charge: absorb what the remaining energy buys.
    absorbed = suit->energy * CR_ARMOR_DAMAGE_ENERGY_DEN
               / CR_ARMOR_DAMAGE_ENERGY_NUM;

    suit->energy = 0;
    suit->mode = CR_SUIT_ARMOR;

    if (absorbed > damage)
    {
        absorbed = damage;
    }

    if (CR_DebugEnabled())
    {
        printf(CR_LOG_PREFIX " armor depleted damage=%d absorbed=%d\n",
               damage, absorbed);
    }

    return damage - absorbed;
}

void CR_SuitOnWeaponFired(player_t *player)
{
    cr_nanosuit_t *suit = SuitForPlayer(player);

    if (suit == NULL)
    {
        return;
    }

    suit->recharge_block_until = leveltime + suit->recharge_delay_tics;

    if (suit->mode == CR_SUIT_CLOAK)
    {
        // Firing breaks the cloak and drains the battery.
        suit->mode = CR_SUIT_ARMOR;
        suit->energy = 0;
        suit->cloak_visible = true;
        suit->cloak_drain_accum = 0;

        if (CR_DebugEnabled())
        {
            printf(CR_LOG_PREFIX " cloak broken by weapon fire\n");
        }
    }
}

fixed_t CR_SuitVisibilityFactor(const player_t *player)
{
    const cr_nanosuit_t *suit = SuitForPlayer(player);

    if (suit == NULL || suit->mode != CR_SUIT_CLOAK || suit->energy <= 0
        || suit->cloak_visible)
    {
        return FRACUNIT;
    }

    if (player->cmd.forwardmove == 0 && player->cmd.sidemove == 0)
    {
        return CR_CLOAK_VIS_IDLE;
    }

    {
        const cr_player_state_t *state = CR_PlayerStateConst(player);

        if (state != NULL && state->sprinting)
        {
            return CR_CLOAK_VIS_RUN;
        }
    }

    return CR_CLOAK_VIS_MOVE;
}

fixed_t CR_SuitMoveFactor(const player_t *player)
{
    const cr_player_state_t *state = CR_PlayerStateConst(player);
    const cr_nanosuit_t *suit;

    if (state == NULL)
    {
        return FRACUNIT;
    }

    suit = &state->suit;

    // ADS takes priority and suspends sprint.
    if (state->ads)
    {
        return CR_MOVE_ADS;
    }

    if (!state->sprinting || CR_SuitSprintBlocked(player) || state->reloading)
    {
        return FRACUNIT;
    }

    if (suit->mode == CR_SUIT_SPEED && suit->energy > 0)
    {
        return CR_MOVE_SPEED;
    }

    return CR_MOVE_SPRINT;
}

fixed_t CR_SuitJumpMomentum(const player_t *player, fixed_t normal_momz)
{
    cr_nanosuit_t *suit = SuitForPlayer(player);

    if (suit == NULL || suit->mode != CR_SUIT_STRENGTH
        || suit->energy < CR_STRENGTH_JUMP_COST)
    {
        return normal_momz;
    }

    suit->energy -= CR_STRENGTH_JUMP_COST;
    suit->recharge_block_until = leveltime + suit->recharge_delay_tics;

    return FixedMul(normal_momz, CR_STRENGTH_JUMP_FACTOR);
}

int CR_SuitMeleeDamage(player_t *player, int base_damage)
{
    cr_nanosuit_t *suit = SuitForPlayer(player);

    if (suit == NULL || suit->mode != CR_SUIT_STRENGTH
        || suit->energy < CR_STRENGTH_MELEE_COST)
    {
        return base_damage;
    }

    suit->energy -= CR_STRENGTH_MELEE_COST;
    suit->recharge_block_until = leveltime + suit->recharge_delay_tics;

    return FixedMul(base_damage, CR_STRENGTH_MELEE_FACTOR);
}

fixed_t CR_SuitRecoilScale(const player_t *player)
{
    const cr_nanosuit_t *suit = SuitForPlayer(player);

    if (suit != NULL && suit->mode == CR_SUIT_STRENGTH)
    {
        return FRACUNIT / 2;
    }

    return FRACUNIT;
}
