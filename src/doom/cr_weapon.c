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
// Crysis weapons. The magazine/reserve pair is the source of truth; the
// vanilla weapon slots only transport psprites and input bits.
//

#include <stdio.h>
#include <string.h>

#include "doomdef.h"
#include "doomstat.h"
#include "d_event.h"
#include "d_items.h"
#include "d_ticcmd.h"
#include "m_random.h"
#include "p_local.h"
#include "p_pspr.h"
#include "s_sound.h"

#include "cr_defs.h"
#include "cr_game.h"
#include "cr_nanosuit.h"
#include "cr_player.h"
#include "cr_sound.h"
#include "cr_weapon.h"
#include "crispy.h"
#include "sounds.h"

// p_pspr.c does not publish this prototype in a header.
void P_SetPsprite(player_t *player, int position, statenum_t stnum);

// Initial tuning; the plan marks these as parameters to be refined by playtest.
static const cr_weapon_def_t cr_weapons[CR_WEAPON_COUNT] =
{
    {
        "MELEE", 20, 0, 0, 0, 0, 0, 0, 0, 0,
        CR_FIRE_SEMI, 0, wp_fist
    },
    {
        "SOCOM", 15, 12, 96, 340, 42, 24, 6, 4, 1000 * FRACUNIT,
        CR_FIRE_SEMI, CR_ATTACH_SUPPRESSOR | CR_ATTACH_REFLEX, wp_pistol
    },
    {
        "SCAR", 18, 30, 210, 600, 56, 32, 8, 4, 1400 * FRACUNIT,
        CR_FIRE_SEMI | CR_FIRE_AUTO,
        CR_ATTACH_SUPPRESSOR | CR_ATTACH_REFLEX | CR_ATTACH_SCOPE, wp_chaingun
    },
    {
        "FY71", 20, 30, 210, 500, 56, 28, 8, 5, 1400 * FRACUNIT,
        CR_FIRE_SEMI | CR_FIRE_AUTO,
        CR_ATTACH_SUPPRESSOR | CR_ATTACH_REFLEX, wp_plasma
    }
};

static const char *const weapon_pickup_messages[CR_WEAPON_COUNT] =
{
    NULL, "SOCOM AMMO", "SCAR AMMO", "FY71 AMMO"
};

static cr_player_state_t *StateForPlayer(player_t *player)
{
    return CR_PlayerState(player);
}

cr_weapon_id_t CR_WeaponIdForPlayer(const player_t *player)
{
    switch (player->readyweapon)
    {
        case wp_pistol:
            return CR_WEAPON_SOCOM;
        case wp_chaingun:
            return CR_WEAPON_SCAR;
        case wp_plasma:
            return CR_WEAPON_FY71;
        default:
            return CR_WEAPON_MELEE;
    }
}

const cr_weapon_def_t *CR_WeaponDef(cr_weapon_id_t id)
{
    if (id < 0 || id >= CR_WEAPON_COUNT)
    {
        return &cr_weapons[CR_WEAPON_MELEE];
    }

    return &cr_weapons[id];
}

const cr_weapon_def_t *CR_WeaponCurrentDef(const player_t *player)
{
    return CR_WeaponDef(CR_WeaponIdForPlayer(player));
}

static int AddReserve(cr_weapon_state_t *weapon, cr_weapon_id_t id,
                      const cr_weapon_def_t *def, int amount)
{
    int room = def->reserve_max - weapon->reserve[id];

    if (room <= 0 || amount <= 0)
    {
        return 0;
    }

    if (amount > room)
    {
        amount = room;
    }

    weapon->reserve[id] += amount;
    return amount;
}

void CR_WeaponReset(player_t *player)
{
    cr_player_state_t *state = StateForPlayer(player);
    cr_weapon_state_t *weapon;
    cr_weapon_id_t id;

    if (state == NULL)
    {
        return;
    }

    weapon = &state->weapon;
    memset(weapon, 0, sizeof(*weapon));

    // The slice loadout owns every mapped weapon from the start.
    player->weaponowned[wp_fist] = true;
    player->weaponowned[wp_pistol] = true;
    player->weaponowned[wp_chaingun] = true;
    player->weaponowned[wp_plasma] = true;

    for (id = CR_WEAPON_MELEE; id < CR_WEAPON_COUNT; ++id)
    {
        const cr_weapon_def_t *def = &cr_weapons[id];

        weapon->magazine[id] = def->magazine_size;
        weapon->reserve[id] = def->reserve_max / 2;
        weapon->fire_mode[id] = (def->fire_modes & CR_FIRE_AUTO)
                                ? CR_FIRE_AUTO : CR_FIRE_SEMI;
        weapon->attachments[id] = 0;
    }

    state->reloading = false;
}

void CR_WeaponLevelStart(player_t *player)
{
    cr_player_state_t *state = StateForPlayer(player);
    cr_weapon_state_t *weapon;

    if (state == NULL)
    {
        return;
    }

    weapon = &state->weapon;
    weapon->reloading = false;
    weapon->attack_held = false;
    weapon->attack_pressed = false;
    weapon->overlay_open = false;
    weapon->overlay_slot = 0;
    state->reloading = false;
}

int CR_WeaponMagazine(const player_t *player)
{
    const cr_player_state_t *state = CR_PlayerStateConst(player);
    const cr_weapon_id_t id = CR_WeaponIdForPlayer(player);

    return state == NULL ? 0 : state->weapon.magazine[id];
}

int CR_WeaponReserve(const player_t *player)
{
    const cr_player_state_t *state = CR_PlayerStateConst(player);
    const cr_weapon_id_t id = CR_WeaponIdForPlayer(player);

    return state == NULL ? 0 : state->weapon.reserve[id];
}

unsigned int CR_WeaponFireMode(const player_t *player)
{
    const cr_player_state_t *state = CR_PlayerStateConst(player);
    const cr_weapon_id_t id = CR_WeaponIdForPlayer(player);

    return state == NULL ? CR_FIRE_SEMI : state->weapon.fire_mode[id];
}

const char *CR_WeaponFireModeName(unsigned int mode)
{
    if (mode & CR_FIRE_BURST)
    {
        return "BURST";
    }

    if (mode & CR_FIRE_AUTO)
    {
        return "AUTO";
    }

    return "SEMI";
}

boolean CR_WeaponIsReloading(const player_t *player)
{
    const cr_player_state_t *state = CR_PlayerStateConst(player);

    return state != NULL && state->weapon.reloading;
}

boolean CR_WeaponIsMelee(const player_t *player)
{
    return CR_WeaponIdForPlayer(player) == CR_WEAPON_MELEE;
}

void CR_WeaponStartReload(player_t *player)
{
    cr_player_state_t *state = StateForPlayer(player);
    cr_weapon_state_t *weapon;
    cr_weapon_id_t id;
    const cr_weapon_def_t *def;

    if (state == NULL || player->playerstate != PST_LIVE)
    {
        return;
    }

    weapon = &state->weapon;
    id = CR_WeaponIdForPlayer(player);
    def = &cr_weapons[id];

    if (id == CR_WEAPON_MELEE || weapon->reloading)
    {
        return;
    }

    if (weapon->magazine[id] >= def->magazine_size)
    {
        return;
    }

    if (weapon->reserve[id] <= 0)
    {
        player->message = "NO RESERVE AMMO";
        return;
    }

    weapon->reloading = true;
    state->reloading = true;
    weapon->reload_end_tic = leveltime + def->reload_tics;
    S_StartSound(player->so, sfx_swtchn);

    if (CR_DebugEnabled())
    {
        printf(CR_LOG_PREFIX " reload start weapon=%s end_tic=%d\n",
               def->name, weapon->reload_end_tic);
    }
}

void CR_WeaponCancelReload(player_t *player)
{
    cr_player_state_t *state = StateForPlayer(player);
    cr_weapon_state_t *weapon;

    if (state == NULL)
    {
        return;
    }

    weapon = &state->weapon;

    if (!weapon->reloading)
    {
        return;
    }

    weapon->reloading = false;
    state->reloading = false;

    if (CR_DebugEnabled())
    {
        printf(CR_LOG_PREFIX " reload cancelled\n");
    }
}

void CR_WeaponNextFireMode(player_t *player)
{
    cr_player_state_t *state = StateForPlayer(player);
    cr_weapon_state_t *weapon;
    cr_weapon_id_t id;
    const cr_weapon_def_t *def;

    if (state == NULL)
    {
        return;
    }

    weapon = &state->weapon;
    id = CR_WeaponIdForPlayer(player);
    def = &cr_weapons[id];

    // Toggle only makes sense when the weapon has more than one mode.
    if ((def->fire_modes & (CR_FIRE_SEMI | CR_FIRE_AUTO))
        != (CR_FIRE_SEMI | CR_FIRE_AUTO))
    {
        return;
    }

    if (weapon->fire_mode[id] & CR_FIRE_AUTO)
    {
        weapon->fire_mode[id] = CR_FIRE_SEMI;
        player->message = "FIRE MODE: SEMI";
    }
    else
    {
        weapon->fire_mode[id] = CR_FIRE_AUTO;
        player->message = "FIRE MODE: AUTO";
    }

    S_StartSound(player->so, sfx_swtchn);

    if (CR_DebugEnabled())
    {
        printf(CR_LOG_PREFIX " fire mode weapon=%s mode=%s\n", def->name,
               CR_WeaponFireModeName(weapon->fire_mode[id]));
    }
}

int CR_WeaponCurrentSpread(const player_t *player)
{
    const cr_player_state_t *state = CR_PlayerStateConst(player);
    const cr_weapon_def_t *def = CR_WeaponCurrentDef(player);
    int spread;

    if (state == NULL || CR_WeaponIsMelee(player))
    {
        return 0;
    }

    spread = state->ads ? def->ads_spread : def->hip_spread;

    // Moving fast costs accuracy at the hip.
    if (!state->ads && state->sprinting)
    {
        spread = spread * 3 / 2;
    }

    return spread;
}

fixed_t CR_WeaponCurrentNoiseRadius(const player_t *player)
{
    const cr_player_state_t *state = CR_PlayerStateConst(player);
    const cr_weapon_id_t id = CR_WeaponIdForPlayer(player);
    const cr_weapon_def_t *def = &cr_weapons[id];
    fixed_t radius = def->noise_radius;

    if (state == NULL)
    {
        return radius;
    }

    if (state->weapon.attachments[id] & CR_ATTACH_SUPPRESSOR)
    {
        radius = FixedMul(radius, 3 * FRACUNIT / 10);
    }

    return radius;
}

static void CR_WeaponShoot(player_t *player, cr_weapon_state_t *weapon,
                           cr_weapon_id_t id, const cr_weapon_def_t *def)
{
    cr_player_state_t *state = StateForPlayer(player);
    angle_t angle = player->mo->angle;
    fixed_t slope;
    int spread = CR_WeaponCurrentSpread(player);
    int tics_per_shot;
    int recoil;

    weapon->magazine[id]--;

    // Psprite animation and muzzle flash come from the mapped vanilla weapon.
    P_SetMobjState(player->mo, S_PLAY_ATK1);
    P_SetPsprite(player, ps_weapon, weaponinfo[player->readyweapon].atkstate);
    P_SetPsprite(player, ps_flash, weaponinfo[player->readyweapon].flashstate);

    // Spread changes the real attack direction.
    if (spread > 0)
    {
        angle += P_SubRandom() * spread;
    }

    slope = P_AimLineAttack(player->mo, angle, MISSILERANGE);
    P_LineAttack(player->mo, angle, MISSILERANGE, slope, def->damage);

    // Functional recoil; ADS and Strength scale it.
    recoil = def->recoil_pitch;
    if (state != NULL && state->ads)
    {
        recoil = recoil * 2 / 3;
    }

    player->recoilpitch += (recoil * CR_SuitRecoilScale(player)) >> FRACBITS;

    tics_per_shot = TICRATE * 60 / def->shots_per_minute;
    if (tics_per_shot < 1)
    {
        tics_per_shot = 1;
    }

    weapon->next_fire_tic = leveltime + tics_per_shot;

    // Audio placeholder per transport slot.
    if (id == CR_WEAPON_FY71)
    {
        S_StartSound(player->so, sfx_plasma);
    }
    else
    {
        S_StartSound(player->so, sfx_pistol);
    }

    // Noise event with the position captured now.
    CR_EmitNoise(player->mo, player->mo->x, player->mo->y,
                 CR_WeaponCurrentNoiseRadius(player),
                 (state != NULL
                  && (state->weapon.attachments[id] & CR_ATTACH_SUPPRESSOR))
                     ? CR_NOISE_SUPPRESSED_GUNSHOT : CR_NOISE_GUNSHOT);

    // A real shot breaks Cloak and blocks recharge.
    CR_SuitOnWeaponFired(player);
}

void CR_WeaponFire(player_t *player)
{
    cr_player_state_t *state = StateForPlayer(player);
    cr_weapon_state_t *weapon;
    cr_weapon_id_t id;
    const cr_weapon_def_t *def;
    unsigned int mode;

    if (!CR_IsActive() || state == NULL)
    {
        return;
    }

    weapon = &state->weapon;
    id = CR_WeaponIdForPlayer(player);
    def = &cr_weapons[id];

    if (id == CR_WEAPON_MELEE)
    {
        // Vanilla animation; A_Punch/A_Saw own the hit and Strength scaling.
        P_SetMobjState(player->mo, S_PLAY_ATK1);
        P_SetPsprite(player, ps_weapon, weaponinfo[player->readyweapon].atkstate);
        return;
    }

    if (player->playerstate != PST_LIVE || !player->health)
    {
        return;
    }

    // Cadence gate first: a short press during cooldown stays buffered.
    if ((int) leveltime < weapon->next_fire_tic)
    {
        return;
    }

    // Semi and burst require a fresh press; auto tracks the held button.
    mode = weapon->fire_mode[id];
    if ((mode & CR_FIRE_AUTO) == 0)
    {
        if (!weapon->attack_pressed)
        {
            return;
        }
    }

    weapon->attack_pressed = false;

    if (weapon->reloading)
    {
        return;
    }

    if (weapon->magazine[id] <= 0)
    {
        // Pulling the trigger dry starts the reload instead.
        CR_WeaponStartReload(player);
        return;
    }

    CR_WeaponShoot(player, weapon, id, def);

    if (CR_DebugEnabled())
    {
        printf(CR_LOG_PREFIX " shot weapon=%s mag=%d reserve=%d tic=%d\n",
               def->name, weapon->magazine[id], weapon->reserve[id], leveltime);
    }
}

boolean CR_WeaponCheckAmmo(player_t *player)
{
    cr_player_state_t *state = StateForPlayer(player);
    cr_weapon_state_t *weapon;
    cr_weapon_id_t id;
    cr_weapon_id_t fallback;

    if (state == NULL)
    {
        return true;
    }

    weapon = &state->weapon;
    id = CR_WeaponIdForPlayer(player);

    if (id == CR_WEAPON_MELEE)
    {
        return true;
    }

    if (weapon->magazine[id] > 0)
    {
        return true;
    }

    if (weapon->reserve[id] > 0)
    {
        CR_WeaponStartReload(player);
        return false;
    }

    // Completely dry: prefer any other loaded weapon, then melee.
    for (fallback = CR_WEAPON_SOCOM; fallback < CR_WEAPON_COUNT; ++fallback)
    {
        if (fallback != id
            && (weapon->magazine[fallback] > 0
                || weapon->reserve[fallback] > 0))
        {
            player->pendingweapon = cr_weapons[fallback].vanilla;
            P_SetPsprite(player, ps_weapon,
                         weaponinfo[player->readyweapon].downstate);
            return false;
        }
    }

    if (player->readyweapon != wp_fist)
    {
        player->pendingweapon = wp_fist;
        P_SetPsprite(player, ps_weapon,
                     weaponinfo[player->readyweapon].downstate);
    }

    return false;
}

boolean CR_WeaponGiveAmmo(player_t *player, ammotype_t ammo, int num,
                          boolean dropped)
{
    cr_player_state_t *state = StateForPlayer(player);
    int amount;
    int added = 0;

    if (state == NULL || ammo == am_noammo || ammo >= NUMAMMO)
    {
        return false;
    }

    if (ammo == am_clip)
    {
        if (num)
        {
            amount = num * clipammo[am_clip];
        }
        else
        {
            amount = clipammo[am_clip] / 2;
        }

        if (gameskill == sk_baby || gameskill == sk_nightmare
            || critical->moreammo)
        {
            amount <<= 1;
        }

        if (dropped)
        {
            amount >>= 1;

            if (!amount)
            {
                amount = 1;
            }
        }

        added += AddReserve(&state->weapon, CR_WEAPON_SOCOM,
                            &cr_weapons[CR_WEAPON_SOCOM], amount / 2);
        added += AddReserve(&state->weapon, CR_WEAPON_SCAR,
                            &cr_weapons[CR_WEAPON_SCAR],
                            amount - amount / 2);
        return added > 0;
    }

    if (ammo == am_cell)
    {
        if (num)
        {
            amount = num * clipammo[am_cell];
        }
        else
        {
            amount = clipammo[am_cell] / 2;
        }

        if (gameskill == sk_baby || gameskill == sk_nightmare
            || critical->moreammo)
        {
            amount <<= 1;
        }

        if (dropped)
        {
            amount >>= 1;

            if (!amount)
            {
                amount = 1;
            }
        }

        added = AddReserve(&state->weapon, CR_WEAPON_FY71,
                           &cr_weapons[CR_WEAPON_FY71], amount);
        return added > 0;
    }

    // Shells and rockets have no weapon in the slice.
    return false;
}

boolean CR_WeaponGiveWeapon(player_t *player, weapontype_t weapon,
                            boolean dropped)
{
    cr_player_state_t *state = StateForPlayer(player);
    cr_weapon_id_t id = CR_WEAPON_MELEE;
    int amount;
    int added;

    if (state == NULL)
    {
        return false;
    }

    switch (weapon)
    {
        case wp_pistol:
            id = CR_WEAPON_SOCOM;
            break;
        case wp_chaingun:
            id = CR_WEAPON_SCAR;
            break;
        case wp_plasma:
            id = CR_WEAPON_FY71;
            break;
        default:
            return false;
    }

    amount = cr_weapons[id].magazine_size * (dropped ? 1 : 2);
    added = AddReserve(&state->weapon, id, &cr_weapons[id], amount);

    player->weaponowned[weapon] = true;
    player->pendingweapon = weapon;
    player->message = weapon_pickup_messages[id];
    S_StartSound(NULL, sfx_wpnup);

    return added > 0;
}

void CR_WeaponTick(player_t *player)
{
    cr_player_state_t *state = StateForPlayer(player);
    cr_weapon_state_t *weapon;
    cr_weapon_id_t id;
    const cr_weapon_def_t *def;
    boolean attack;

    if (state == NULL)
    {
        return;
    }

    weapon = &state->weapon;
    id = CR_WeaponIdForPlayer(player);
    def = &cr_weapons[id];

    // Track the raw attack edge for semi/burst fire modes.
    attack = (player->cmd.buttons & BT_ATTACK) != 0;

    if (attack && !weapon->attack_held)
    {
        weapon->attack_pressed = true;
    }

    weapon->attack_held = attack;

    if (player->playerstate != PST_LIVE)
    {
        weapon->attack_pressed = false;
    }

    if (state->buttons_pressed & CR_BT2_RELOAD)
    {
        CR_WeaponStartReload(player);
    }

    if (state->buttons_pressed & CR_BT2_FIREMODE)
    {
        CR_WeaponNextFireMode(player);
    }

    if (!weapon->reloading)
    {
        return;
    }

    if (player->playerstate != PST_LIVE || player->pendingweapon != wp_nochange)
    {
        CR_WeaponCancelReload(player);
        return;
    }

    if ((int) leveltime >= weapon->reload_end_tic)
    {
        int needed = def->magazine_size - weapon->magazine[id];
        int loaded = needed < weapon->reserve[id]
                     ? needed : weapon->reserve[id];

        weapon->magazine[id] += loaded;
        weapon->reserve[id] -= loaded;
        weapon->reloading = false;
        state->reloading = false;
        player->message = "RELOADED";

        if (CR_DebugEnabled())
        {
            printf(CR_LOG_PREFIX " reload done weapon=%s mag=%d reserve=%d\n",
                   def->name, weapon->magazine[id], weapon->reserve[id]);
        }
    }
}
