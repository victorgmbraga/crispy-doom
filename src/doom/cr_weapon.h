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
// Crysis weapons: loadout, magazines, reserve ammo, reload, fire modes,
// spread and recoil. Vanilla weapon slots are transport only.
//

#ifndef CR_WEAPON_H
#define CR_WEAPON_H

#include "doomdef.h"
#include "d_items.h"
#include "d_player.h"
#include "m_fixed.h"

typedef enum
{
    CR_WEAPON_MELEE = 0,
    CR_WEAPON_SOCOM,
    CR_WEAPON_SCAR,
    CR_WEAPON_FY71,
    CR_WEAPON_COUNT
} cr_weapon_id_t;

typedef enum
{
    CR_FIRE_SEMI = 1 << 0,
    CR_FIRE_AUTO = 1 << 1,
    CR_FIRE_BURST = 1 << 2
} cr_fire_mode_mask_t;

#define CR_ATTACH_SUPPRESSOR (1u << 0)
#define CR_ATTACH_REFLEX     (1u << 1)
#define CR_ATTACH_SCOPE      (1u << 2)
#define CR_ATTACH_LASER      (1u << 3)

typedef struct
{
    const char *name;
    int damage;
    int magazine_size;
    int reserve_max;
    int shots_per_minute;
    int reload_tics;
    int hip_spread;      // Multiples of P_SubRandom() applied to aim angle.
    int ads_spread;
    int recoil_pitch;    // Recoil units added to player->recoilpitch.
    fixed_t noise_radius;
    unsigned int fire_modes;
    unsigned int attachment_mask;
    weapontype_t vanilla; // Transport slot inside the Doom weapon system.
} cr_weapon_def_t;

typedef struct
{
    int magazine[CR_WEAPON_COUNT];
    int reserve[CR_WEAPON_COUNT];
    unsigned int fire_mode[CR_WEAPON_COUNT];
    unsigned int attachments[CR_WEAPON_COUNT];
    int next_fire_tic;
    int reload_end_tic;
    boolean reloading;
    // Attack edges survive across tics until a shot consumes them.
    boolean attack_held;
    boolean attack_pressed;
    // Attachment overlay (Phase 5).
    boolean overlay_open;
    int overlay_slot;
} cr_weapon_state_t;

// Loadout for a new game.
void CR_WeaponReset(player_t *player);
// Transient state never survives a level transition.
void CR_WeaponLevelStart(player_t *player);
// One tick: reload timing, edges, fire mode, overlay.
void CR_WeaponTick(player_t *player);

// Replaces P_FireWeapon(); owns the single Crysis firing path.
void CR_WeaponFire(player_t *player);
// Replaces P_CheckAmmo() while the mode is active.
boolean CR_WeaponCheckAmmo(player_t *player);

// Item pickups adapt into reserve ammo / replenishment.
boolean CR_WeaponGiveAmmo(player_t *player, ammotype_t ammo, int num,
                          boolean dropped);
boolean CR_WeaponGiveWeapon(player_t *player, weapontype_t weapon,
                            boolean dropped);

void CR_WeaponStartReload(player_t *player);
void CR_WeaponCancelReload(player_t *player);
void CR_WeaponNextFireMode(player_t *player);

// Queries for HUD, perception and the suit.
cr_weapon_id_t CR_WeaponIdForPlayer(const player_t *player);
const cr_weapon_def_t *CR_WeaponDef(cr_weapon_id_t id);
const cr_weapon_def_t *CR_WeaponCurrentDef(const player_t *player);
int CR_WeaponMagazine(const player_t *player);
int CR_WeaponReserve(const player_t *player);
unsigned int CR_WeaponFireMode(const player_t *player);
const char *CR_WeaponFireModeName(unsigned int mode);
boolean CR_WeaponIsReloading(const player_t *player);
boolean CR_WeaponIsMelee(const player_t *player);
int CR_WeaponCurrentSpread(const player_t *player);
fixed_t CR_WeaponCurrentNoiseRadius(const player_t *player);

#endif
