/* Phase 4 contract tests: compile the real weapon module with small engine
 * boundary stubs. No replacement implementation of its logic. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cr_defs.h"
#include "cr_game.h"
#include "cr_nanosuit.h"
#include "cr_player.h"
#include "cr_sound.h"
#include "cr_weapon.h"
#include "crispy.h"
#include "doomstat.h"
#include "d_items.h"
#include "d_event.h"
#include "m_random.h"
#include "p_pspr.h"
#include "s_sound.h"

player_t players[MAXPLAYERS];
boolean playeringame[MAXPLAYERS];
gamestate_t gamestate = GS_LEVEL;
skill_t gameskill = sk_medium;
boolean menuactive;
boolean paused;
int consoleplayer;
int gametic;
int leveltime;
weaponinfo_t weaponinfo[NUMWEAPONS];
int clipammo[NUMAMMO] = {4, 8, 8, 4};
crispy_t cr_crispy_data;
crispy_t *const crispy = &cr_crispy_data;
const crispy_t *critical = &cr_crispy_data;
int cr_psprite_calls;
int cr_damage_recorded;
int cr_noise_alerts; // Not used; kept for parity with the engine surface.

static boolean active = true;
static int assertions;
static int subrandom;

boolean CR_IsActive(void) { return active; }
boolean CR_DebugEnabled(void) { return false; }
int P_SubRandom(void) { return subrandom; }
int P_Random(void) { return 0; }

void P_SetPsprite(player_t *player, int position, statenum_t stnum)
{
    (void) player;
    (void) position;
    (void) stnum;
    ++cr_psprite_calls;
}

boolean P_SetMobjState(mobj_t *mobj, statenum_t state)
{
    (void) mobj;
    (void) state;
    return true;
}

fixed_t P_AimLineAttack(mobj_t *t1, angle_t angle, fixed_t distance)
{
    (void) t1;
    (void) angle;
    (void) distance;
    return 0;
}

void P_LineAttack(mobj_t *t1, angle_t angle, fixed_t distance, fixed_t slope,
                  int damage)
{
    (void) t1;
    (void) angle;
    (void) distance;
    (void) slope;
    cr_damage_recorded += damage;
}

void S_StartSound(void *origin, int sound_id)
{
    (void) origin;
    (void) sound_id;
}

#define CHECK(test) do { ++assertions; if (!(test)) { \
    fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #test); exit(1); \
} } while (0)

static cr_player_state_t *State(void)
{
    cr_player_state_t *state = CR_PlayerState(&players[0]);
    if (state == NULL) { fputs("missing player state\n", stderr); exit(1); }
    return state;
}

static void Tic(void)
{
    CR_WeaponTick(&players[0]);
}

static void Press(void)
{
    players[0].cmd.buttons = BT_ATTACK;
    Tic();
    CR_WeaponFire(&players[0]);
}

static void Hold(void)
{
    players[0].cmd.buttons = BT_ATTACK;
    Tic();
    CR_WeaponFire(&players[0]);
}

static void Release(void)
{
    players[0].cmd.buttons = 0;
    Tic();
}

int main(void)
{
    cr_player_state_t *state;
    mobj_t actor;

    memset(&actor, 0, sizeof(actor));
    actor.health = 100;
    actor.x = 100 * FRACUNIT;
    actor.y = 200 * FRACUNIT;
    players[0].mo = &actor;
    players[0].health = 100;
    players[0].playerstate = PST_LIVE;
    players[0].readyweapon = wp_pistol;
    players[0].pendingweapon = wp_nochange;
    playeringame[0] = true;

    CR_PlayerReset(&players[0]);
    state = State();

    /* Loadout: every mapped weapon is owned and loaded. */
    CHECK(players[0].weaponowned[wp_fist]);
    CHECK(players[0].weaponowned[wp_pistol]);
    CHECK(players[0].weaponowned[wp_chaingun]);
    CHECK(players[0].weaponowned[wp_plasma]);
    CHECK(CR_WeaponIdForPlayer(&players[0]) == CR_WEAPON_SOCOM);
    CHECK(CR_WeaponMagazine(&players[0]) == 12);
    CHECK(CR_WeaponReserve(&players[0]) == 48);
    CHECK(state->weapon.magazine[CR_WEAPON_SCAR] == 30);
    CHECK(state->weapon.reserve[CR_WEAPON_SCAR] == 105);
    CHECK(state->weapon.magazine[CR_WEAPON_FY71] == 30);
    CHECK(CR_WeaponFireMode(&players[0]) == CR_FIRE_SEMI);
    CHECK(!CR_WeaponIsReloading(&players[0]));

    /* Semi: one shot per press; holding does not repeat. */
    leveltime = 0;
    Press();
    CHECK(CR_WeaponMagazine(&players[0]) == 11);
    CHECK(cr_damage_recorded == 15);
    Hold();
    CHECK(CR_WeaponMagazine(&players[0]) == 11);
    leveltime += 20;
    Hold();
    CHECK(CR_WeaponMagazine(&players[0]) == 11);
    Release();
    Press();
    CHECK(CR_WeaponMagazine(&players[0]) == 10);

    /* Auto: holds fire at the cadence after the cooldown. */
    players[0].readyweapon = wp_chaingun;
    leveltime += 100;
    players[0].cmd.buttons = 0;
    Tic();
    Press();
    CHECK(CR_WeaponMagazine(&players[0]) == 29);
    leveltime += 3; // 600 RPM: one shot every 3 tics.
    Hold();
    CHECK(CR_WeaponMagazine(&players[0]) == 28);
    Hold(); // Same tic cadence: no shot.
    CHECK(CR_WeaponMagazine(&players[0]) == 28);
    Release();

    /* Fire mode toggle only affects multi-mode weapons. */
    state->buttons_pressed = CR_BT2_FIREMODE;
    Tic();
    CHECK(CR_WeaponFireMode(&players[0]) == CR_FIRE_SEMI);
    state->buttons_pressed = CR_BT2_FIREMODE;
    Tic();
    CHECK(CR_WeaponFireMode(&players[0]) == CR_FIRE_AUTO);
    CHECK(!strcmp(CR_WeaponFireModeName(CR_FIRE_AUTO), "AUTO"));
    players[0].readyweapon = wp_pistol;
    state->buttons_pressed = CR_BT2_FIREMODE;
    Tic();
    CHECK(CR_WeaponFireMode(&players[0]) == CR_FIRE_SEMI);
    players[0].readyweapon = wp_chaingun;

    /* Dry fire starts a reload; completion conserves total ammo. */
    state->weapon.magazine[CR_WEAPON_SCAR] = 0;
    state->weapon.reserve[CR_WEAPON_SCAR] = 105;
    leveltime += 100;
    players[0].cmd.buttons = 0;
    Tic();
    Press();
    CHECK(CR_WeaponIsReloading(&players[0]));
    CHECK(CR_WeaponMagazine(&players[0]) == 0);
    CHECK(state->reloading);
    leveltime += 56;
    Tic();
    CHECK(!CR_WeaponIsReloading(&players[0]));
    CHECK(CR_WeaponMagazine(&players[0]) == 30);
    CHECK(CR_WeaponReserve(&players[0]) == 75);
    CHECK(0 + 105 == 30 + 75);

    /* A partial reserve loads only what exists. */
    state->weapon.magazine[CR_WEAPON_SCAR] = 0;
    state->weapon.reserve[CR_WEAPON_SCAR] = 7;
    leveltime += 100;
    players[0].cmd.buttons = 0;
    Tic();
    Press();
    leveltime += 56;
    Tic();
    CHECK(CR_WeaponMagazine(&players[0]) == 7);
    CHECK(CR_WeaponReserve(&players[0]) == 0);

    /* Weapon switch cancels a reload without transferring ammo. */
    state->weapon.magazine[CR_WEAPON_SCAR] = 0;
    state->weapon.reserve[CR_WEAPON_SCAR] = 20;
    leveltime += 100;
    players[0].cmd.buttons = 0;
    Tic();
    Press();
    CHECK(CR_WeaponIsReloading(&players[0]));
    players[0].pendingweapon = wp_plasma;
    Tic();
    CHECK(!CR_WeaponIsReloading(&players[0]));
    CHECK(state->weapon.magazine[CR_WEAPON_SCAR] == 0);
    CHECK(state->weapon.reserve[CR_WEAPON_SCAR] == 20);
    players[0].pendingweapon = wp_nochange;

    /* Manual reload never double-loads and refuses full/empty cases. */
    state->weapon.magazine[CR_WEAPON_SCAR] = 30;
    state->buttons_pressed = CR_BT2_RELOAD;
    Tic();
    CHECK(!CR_WeaponIsReloading(&players[0]));
    state->weapon.magazine[CR_WEAPON_SCAR] = 10;
    state->weapon.reserve[CR_WEAPON_SCAR] = 0;
    state->buttons_pressed = CR_BT2_RELOAD;
    Tic();
    CHECK(!CR_WeaponIsReloading(&players[0]));

    /* Melee has no magazine and always passes the ammo check. */
    players[0].readyweapon = wp_fist;
    CHECK(CR_WeaponIsMelee(&players[0]));
    CHECK(CR_WeaponCheckAmmo(&players[0]));
    Press();
    CHECK(CR_WeaponCheckAmmo(&players[0]));

    /* Dry weapons fall back to a loaded one, then to melee. */
    state->weapon.magazine[CR_WEAPON_SCAR] = 0;
    state->weapon.reserve[CR_WEAPON_SCAR] = 0;
    state->weapon.magazine[CR_WEAPON_FY71] = 0;
    state->weapon.reserve[CR_WEAPON_FY71] = 0;
    state->weapon.magazine[CR_WEAPON_SOCOM] = 5;
    state->weapon.reserve[CR_WEAPON_SOCOM] = 0;
    players[0].readyweapon = wp_chaingun;
    CHECK(!CR_WeaponCheckAmmo(&players[0]));
    CHECK(players[0].pendingweapon == wp_pistol);
    players[0].pendingweapon = wp_nochange;
    state->weapon.magazine[CR_WEAPON_SOCOM] = 0;
    CHECK(!CR_WeaponCheckAmmo(&players[0]));
    CHECK(players[0].pendingweapon == wp_fist);
    players[0].pendingweapon = wp_nochange;

    /* Ammo pickups feed independent reserves. */
    state->weapon.reserve[CR_WEAPON_SOCOM] = 0;
    state->weapon.reserve[CR_WEAPON_SCAR] = 0;
    state->weapon.reserve[CR_WEAPON_FY71] = 0;
    CHECK(CR_WeaponGiveAmmo(&players[0], am_clip, 1, false));
    CHECK(state->weapon.reserve[CR_WEAPON_SOCOM] == 2);
    CHECK(state->weapon.reserve[CR_WEAPON_SCAR] == 2);
    CHECK(state->weapon.reserve[CR_WEAPON_FY71] == 0);
    CHECK(CR_WeaponGiveAmmo(&players[0], am_cell, 1, false));
    CHECK(state->weapon.reserve[CR_WEAPON_FY71] == 8);
    CHECK(!CR_WeaponGiveAmmo(&players[0], am_shell, 1, false));
    CHECK(!CR_WeaponGiveAmmo(&players[0], am_misl, 1, false));

    /* Weapon pickups grant reserve ammo for their Crysis equivalent. */
    state->weapon.reserve[CR_WEAPON_SOCOM] = 0;
    CHECK(CR_WeaponGiveWeapon(&players[0], wp_pistol, false));
    CHECK(state->weapon.reserve[CR_WEAPON_SOCOM] == 24);
    CHECK(!CR_WeaponGiveWeapon(&players[0], wp_shotgun, false));
    CHECK(!CR_WeaponGiveWeapon(&players[0], wp_chainsaw, false));

    /* Spread: ADS is tighter, sprinting is wider; melee has none. */
    players[0].readyweapon = wp_pistol;
    state->ads = false;
    state->sprinting = false;
    CHECK(CR_WeaponCurrentSpread(&players[0]) == 24);
    state->ads = true;
    CHECK(CR_WeaponCurrentSpread(&players[0]) == 6);
    state->ads = false;
    state->sprinting = true;
    CHECK(CR_WeaponCurrentSpread(&players[0]) == 36);
    state->sprinting = false;
    players[0].readyweapon = wp_fist;
    CHECK(CR_WeaponCurrentSpread(&players[0]) == 0);

    /* Suppressor shrinks the declared noise radius and changes the type. */
    players[0].readyweapon = wp_pistol;
    state->weapon.attachments[CR_WEAPON_SOCOM] = 0;
    CHECK(CR_WeaponCurrentNoiseRadius(&players[0]) == 1000 * FRACUNIT);
    state->weapon.attachments[CR_WEAPON_SOCOM] = CR_ATTACH_SUPPRESSOR;
    CHECK(CR_WeaponCurrentNoiseRadius(&players[0])
          == FixedMul(1000 * FRACUNIT, 3 * FRACUNIT / 10));

    /* A shot emits exactly one noise event with the position captured now. */
    CR_SoundReset();
    state->weapon.attachments[CR_WEAPON_SOCOM] = 0;
    state->weapon.magazine[CR_WEAPON_SOCOM] = 12;
    state->weapon.reserve[CR_WEAPON_SOCOM] = 48;
    leveltime += 100;
    players[0].cmd.buttons = 0;
    Tic();
    Press();
    CHECK(CR_SoundNoiseCount() == 1);
    CHECK(CR_SoundLastNoise()->x == actor.x);
    CHECK(CR_SoundLastNoise()->y == actor.y);
    CHECK(CR_SoundLastNoise()->type == CR_NOISE_GUNSHOT);

    /* Firing breaks Cloak through the suit hook. */
    CR_SuitSetMode(&players[0], CR_SUIT_CLOAK);
    state->suit.energy = 100;
    leveltime += 100;
    players[0].cmd.buttons = 0;
    Tic();
    Press();
    CHECK(state->suit.mode == CR_SUIT_ARMOR);
    CHECK(state->suit.energy == 0);

    /* Level start cancels transient reload and edge state. */
    state->weapon.reloading = true;
    state->reloading = true;
    state->weapon.attack_pressed = true;
    CR_PlayerLevelStart(&players[0]);
    CHECK(!CR_WeaponIsReloading(&players[0]));
    CHECK(!state->reloading);
    CHECK(!state->weapon.attack_pressed);

    /* Vanilla gate: the weapon path is inert without the mode. */
    active = false;
    state->weapon.magazine[CR_WEAPON_SOCOM] = 12;
    cr_damage_recorded = 0;
    players[0].cmd.buttons = BT_ATTACK;
    CR_WeaponTick(&players[0]);
    CR_WeaponFire(&players[0]);
    CHECK(cr_damage_recorded == 0);
    CHECK(state->weapon.magazine[CR_WEAPON_SOCOM] == 12);
    active = true;

    printf("F4_LOGIC PASS assertions=%d\n", assertions);
    return 0;
}
