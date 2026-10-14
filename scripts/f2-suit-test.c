/* Phase 2 contract tests: compile the real Nanosuit and player modules with
 * small engine boundary stubs. No replacement implementation of their logic. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cr_defs.h"
#include "cr_game.h"
#include "cr_nanosuit.h"
#include "cr_player.h"
#include "doomstat.h"
#include "m_config.h"

player_t players[MAXPLAYERS];
boolean playeringame[MAXPLAYERS];
gamestate_t gamestate = GS_LEVEL;
boolean menuactive;
boolean paused;
int consoleplayer;
int gametic;
int leveltime;
static boolean active = true;
static int assertions;

boolean CR_IsActive(void) { return active; }
boolean CR_DebugEnabled(void) { return false; }

/* Weapon module boundary: the player module resets loadout here. */
void CR_WeaponReset(player_t *player) { (void) player; }
void CR_WeaponLevelStart(player_t *player) { (void) player; }

void M_BindIntVariable(const char *name, int *value)
{
    (void) name;
    (void) value;
}

#define CHECK(test) do { ++assertions; if (!(test)) { \
    fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #test); exit(1); \
} } while (0)

static player_t *Player(void)
{
    return &players[0];
}

static cr_player_state_t *State(void)
{
    cr_player_state_t *state = CR_PlayerState(Player());
    if (state == NULL) { fputs("missing player state\n", stderr); exit(1); }
    return state;
}

static void SetLeveltime(int tics)
{
    leveltime = tics;
}

int main(void)
{
    cr_player_state_t *state;
    mobj_t actor;
    fixed_t normal_momz = 8 * FRACUNIT;
    int i;

    memset(&actor, 0, sizeof(actor));
    actor.health = 100;
    Player()->mo = &actor;
    Player()->health = 100;
    Player()->playerstate = PST_LIVE;
    playeringame[0] = true;

    CR_PlayerReset(Player());
    state = State();

    /* Reset initializes a full battery in Armor mode. */
    CHECK(state->initialized);
    CHECK(state->suit.mode == CR_SUIT_ARMOR);
    CHECK(state->suit.energy == CR_SUIT_MAX_ENERGY);
    CHECK(state->suit.max_energy == CR_SUIT_MAX_ENERGY);
    CHECK(state->suit.recharge_delay_tics == CR_SUIT_RECHARGE_DELAY_TICS);

    /* Mode cycling through Q edges and direct setters. */
    SetLeveltime(0);
    state->buttons_pressed = CR_BT2_SUIT_NEXT;
    CR_SuitTick(Player());
    CHECK(state->suit.mode == CR_SUIT_STRENGTH);
    state->buttons_pressed = CR_BT2_SUIT_NEXT;
    CR_SuitTick(Player());
    CHECK(state->suit.mode == CR_SUIT_SPEED);
    state->buttons_pressed = CR_BT2_SUIT_NEXT;
    CR_SuitTick(Player());
    CHECK(state->suit.mode == CR_SUIT_CLOAK);
    state->buttons_pressed = CR_BT2_SUIT_NEXT;
    CR_SuitTick(Player());
    CHECK(state->suit.mode == CR_SUIT_ARMOR);
    state->buttons_pressed = 0;
    CHECK(!strcmp(CR_SuitModeName(CR_SUIT_CLOAK), "CLOAK"));
    CHECK(CR_SuitIsMode(Player(), CR_SUIT_ARMOR));

    /* Strength: jump impulse and melee damage cost energy; Armor does not. */
    CR_SuitSetMode(Player(), CR_SUIT_STRENGTH);
    state->suit.energy = CR_SUIT_MAX_ENERGY;
    CHECK(CR_SuitJumpMomentum(Player(), normal_momz)
          == FixedMul(normal_momz, CR_STRENGTH_JUMP_FACTOR));
    CHECK(state->suit.energy == CR_SUIT_MAX_ENERGY - CR_STRENGTH_JUMP_COST);
    CHECK(CR_SuitMeleeDamage(Player(), 10)
          == FixedMul(10, CR_STRENGTH_MELEE_FACTOR));
    CHECK(state->suit.energy
          == CR_SUIT_MAX_ENERGY - CR_STRENGTH_JUMP_COST - CR_STRENGTH_MELEE_COST);
    CHECK(CR_SuitRecoilScale(Player()) == FRACUNIT / 2);

    CR_SuitSetMode(Player(), CR_SUIT_ARMOR);
    CHECK(CR_SuitJumpMomentum(Player(), normal_momz) == normal_momz);
    CHECK(CR_SuitMeleeDamage(Player(), 10) == 10);
    CHECK(CR_SuitRecoilScale(Player()) == FRACUNIT);

    /* Strength costs are refused when the battery cannot pay them. */
    CR_SuitSetMode(Player(), CR_SUIT_STRENGTH);
    state->suit.energy = CR_STRENGTH_JUMP_COST - 1;
    CHECK(CR_SuitJumpMomentum(Player(), normal_momz) == normal_momz);
    CHECK(state->suit.energy == CR_STRENGTH_JUMP_COST - 1);
    state->suit.energy = CR_STRENGTH_MELEE_COST - 1;
    CHECK(CR_SuitMeleeDamage(Player(), 10) == 10);
    CHECK(state->suit.energy == CR_STRENGTH_MELEE_COST - 1);

    /* Armor: full absorption, damage notes, and the recharge delay. */
    CR_SuitSetMode(Player(), CR_SUIT_ARMOR);
    state->suit.energy = 100;
    SetLeveltime(100);
    CHECK(CR_SuitAbsorbDamage(Player(), 30) == 0);
    CHECK(state->suit.energy == 70);
    CHECK(state->last_damage_tic == 100);
    CHECK(state->suit.recharge_block_until
          == 100 + CR_SUIT_RECHARGE_DELAY_TICS);
    CR_SuitTick(Player());
    CHECK(state->suit.energy == 70); // Delay has not elapsed.
    SetLeveltime(100 + CR_SUIT_RECHARGE_DELAY_TICS);
    CR_SuitTick(Player());
    CHECK(state->suit.energy == 71);

    /* Partial absorption when energy covers only part of the damage. */
    state->suit.energy = 10;
    SetLeveltime(200);
    CHECK(CR_SuitAbsorbDamage(Player(), 30) == 20);
    CHECK(state->suit.energy == 0);
    CHECK(state->suit.mode == CR_SUIT_ARMOR);

    /* No absorption outside Armor or with no charge. */
    state->suit.energy = 50;
    CR_SuitSetMode(Player(), CR_SUIT_SPEED);
    CHECK(CR_SuitAbsorbDamage(Player(), 12) == 12);
    CHECK(state->suit.energy == 50);
    CR_SuitSetMode(Player(), CR_SUIT_ARMOR);
    state->suit.energy = 0;
    CHECK(CR_SuitAbsorbDamage(Player(), 12) == 12);
    CHECK(state->last_damage_tic == 200);

    /* Recharge clamps at max and health regen notes reset the accumulator. */
    state->health_regen_accumulator = 3;
    state->suit.energy = CR_SUIT_MAX_ENERGY - 1;
    SetLeveltime(300);
    CR_SuitTick(Player());
    CHECK(state->suit.energy == CR_SUIT_MAX_ENERGY);
    CR_PlayerNoteDamage(Player());
    CHECK(state->health_regen_accumulator == 0);
    CHECK(state->last_damage_tic == 300);

    /* Speed sprint: movement factor with and without charge, plus drain. */
    CR_SuitSetMode(Player(), CR_SUIT_SPEED);
    state->suit.energy = 100;
    state->sprinting = true;
    state->ads = false;
    SetLeveltime(400);
    CHECK(CR_SuitMoveFactor(Player()) == CR_MOVE_SPEED);
    for (i = 0; i < CR_SPEED_SPRINT_DRAIN_TICS; ++i)
    {
        Player()->cmd.forwardmove = 25;
        CR_SuitTick(Player());
    }
    CHECK(state->suit.energy == 99);
    CHECK(state->suit.mode == CR_SUIT_SPEED);

    /* Sprint without Speed mode is the plain run factor and costs nothing. */
    state->suit.energy = 100;
    CR_SuitSetMode(Player(), CR_SUIT_ARMOR);
    CR_SuitTick(Player());
    CHECK(CR_SuitMoveFactor(Player()) == CR_MOVE_SPRINT);
    CHECK(state->suit.energy == 100);

    /* ADS takes priority over sprint. */
    state->ads = true;
    CHECK(CR_SuitMoveFactor(Player()) == CR_MOVE_ADS);
    state->ads = false;

    /* Depletion drops Speed back to Armor and blocks the bonus. */
    CR_SuitSetMode(Player(), CR_SUIT_SPEED);
    state->suit.energy = 1;
    for (i = 0; i < CR_SPEED_SPRINT_DRAIN_TICS * 2; ++i)
    {
        Player()->cmd.forwardmove = 25;
        CR_SuitTick(Player());
    }
    CHECK(state->suit.energy == 0);
    CHECK(state->suit.mode == CR_SUIT_ARMOR);
    CHECK(CR_SuitMoveFactor(Player()) == CR_MOVE_SPRINT);
    CHECK(!CR_SuitSprintBlocked(Player()));

    /* Cloak: idle/move/run visibility and fractional drain. */
    CR_SuitSetMode(Player(), CR_SUIT_CLOAK);
    state->suit.energy = 100;
    state->sprinting = false;
    Player()->cmd.forwardmove = 0;
    CHECK(CR_SuitVisibilityFactor(Player()) == CR_CLOAK_VIS_IDLE);
    for (i = 0; i < CR_CLOAK_IDLE_DRAIN_TICS; ++i)
    {
        CR_SuitTick(Player());
    }
    CHECK(state->suit.energy == 99);
    Player()->cmd.forwardmove = 25;
    CHECK(CR_SuitVisibilityFactor(Player()) == CR_CLOAK_VIS_MOVE);
    state->sprinting = true;
    CHECK(CR_SuitVisibilityFactor(Player()) == CR_CLOAK_VIS_RUN);

    /* Firing breaks Cloak, empties the battery and reveals until recharged. */
    CR_SuitSetMode(Player(), CR_SUIT_CLOAK);
    state->suit.energy = 100;
    CR_SuitOnWeaponFired(Player());
    CHECK(state->suit.mode == CR_SUIT_ARMOR);
    CHECK(state->suit.energy == 0);
    CHECK(state->suit.cloak_visible);
    CHECK(CR_SuitVisibilityFactor(Player()) == FRACUNIT);
    state->suit.energy = CR_SUIT_MAX_ENERGY / 4;
    CR_SuitTick(Player());
    CHECK(!state->suit.cloak_visible);
    state->sprinting = false;
    Player()->cmd.forwardmove = 25;
    CR_SuitSetMode(Player(), CR_SUIT_CLOAK);
    CHECK(CR_SuitVisibilityFactor(Player()) == CR_CLOAK_VIS_MOVE);

    /* Dead players do not recharge or drain. */
    Player()->playerstate = PST_DEAD;
    CR_SuitSetMode(Player(), CR_SUIT_ARMOR);
    state->suit.energy = 10;
    SetLeveltime(900);
    CR_SuitTick(Player());
    CHECK(state->suit.energy == 10);
    Player()->playerstate = PST_LIVE;

    /* CR_SuitConsume clamps at zero and drops active modes. */
    CR_SuitSetMode(Player(), CR_SUIT_SPEED);
    state->suit.energy = 5;
    CHECK(!CR_SuitConsume(Player(), 6));
    CHECK(state->suit.energy == 5);
    CHECK(CR_SuitConsume(Player(), 5));
    CHECK(state->suit.energy == 0);
    CHECK(state->suit.mode == CR_SUIT_ARMOR);

    /* Reset returns a depleted suit to a fresh loadout. */
    CR_PlayerReset(Player());
    CHECK(state->suit.energy == CR_SUIT_MAX_ENERGY);
    CHECK(state->suit.mode == CR_SUIT_ARMOR);

    /* Vanilla gate: consume and absorb never mutate without the mode. */
    active = false;
    state->suit.energy = 42;
    CHECK(CR_SuitAbsorbDamage(Player(), 10) == 10);
    CHECK(!CR_SuitConsume(Player(), 10));
    CHECK(state->suit.energy == 42);
    active = true;

    printf("F2_LOGIC PASS assertions=%d\n", assertions);
    return 0;
}
