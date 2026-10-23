# Level Budgets — Rift Runner

All values match `src/logic/config.gd`. Update this doc whenever a level changes.

---

## Level 1 — Moon (Tutorial)

### Side-View Sketch

```
X=0            X=600      X=1000       X=1600               X=2400
┌──────────────┐          ┌────────────┬────────────────────────┐
│ SPAWN        │   PIT    │            │                        │
│ ●            │  (gap)   │ [portal2↕] │                        │
│ [portal1↕]   │          │ [spike]    │ [cell]  [part]  [EXIT] │
│ [crate]      │          │ ▲▲▲▲▲▲▲▲▲  │                        │
│ [plate] [cell│          │ (360 wide) │ ▓▓▓ raised shelf ▓▓▓▓▓ │
│▓▓▓FLOOR▓▓▓▓▓▓│←  400 →  │▓▓▓FLOOR▓▓▓▓│▓▓▓▓▓▓ (h:140) ▓▓▓▓▓▓▓▓▓│
└──────────────┴──────────┴────────────┴────────────────────────┘
Y=680 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

World A: pit (600-1000), portal 1 (x=220), portal 2 (x=1030), spike (x=1100), cells, part, exit.
World B: crate + plate objective, editBlock-bridge over pit (duplicate), editBlock-spike (delete).
```

### Points Budget

| Event                                    | EP Change | Running Total |
|------------------------------------------|-----------|---------------|
| Start                                    | +30       | 30            |
| Energy cell #1 (ground)                  | +5        | 35            |
| Portal 1 → B, push_block objective       | +25       | 60            |
| Time bonus (within 30 s)                 | +10       | 70            |
| Duplicate bridge (skill in B)            | −20       | 50            |
| Clear obstacle reward                    | +10       | 60            |
| Portal 1 → A, cross bridge to x=1000     | —         | 60            |
| Portal 2 → B                             | —         | 60            |
| Delete spike (skill in B)                | −15       | 45            |
| Clear obstacle reward                    | +10       | 55            |
| Portal 2 → A, walk past cleared spikes   | —         | 55            |
| Energy cell #2                           | +5        | 60            |
| Collect ship part (Fuel Cell)            | +30       | 90            |
| Reach exit, 3 lives left                 | +30       | 120           |

**Minimum to finish (no deaths, no time bonus, skip 1 cell):**
30 + 5 + 25 − 15 + 10 − 20 + 10 + 30 = **75 EP** (very generous)

**After 1 death (−20 EP, 2 lives left, +20 at end instead of +30):**
75 − 20 − 10 = **45 EP** — still completable ✓

### Solvability Check

- Player starts with 30 EP.
- Must spend: Delete 15 + Duplicate 20 = **35 EP** on skills.
- Earns before spending: energy cell +5, B objective +25 = **+30** → total 60 EP before skills.
- After skills: 60 − 35 + 20 (clear rewards) = **45 EP** remaining.
- Remaining rewards: cell +5, part +30, lives +30 = **+65** → finish at 110+.
- Even after 1 death: 45 − 20 + 5 + 30 + 20 = **80 EP**. ✓ Generous.

---

## Level 2 — Mars

### Side-View Sketch

```
X=0          X=500  X=800    X=1300  X=1400  X=1700     X=1900 X=2000       X=2800
┌────────────┐      ┌────────┐      ┌───────┐▓▓wall▓▓   step ┌────────────────────┐
│            │      │        │      │       │▓ h200 ▓   ▓▓▓  │                   │
│  SPAWN ●   │WIDE  │ledge   │ gap  │[p2↕]  │               │  [part]   [EXIT]  │
│  [portal1] │ PIT  │[cell2] │(100) │[cell3]│               │                   │
│  [crate]   │(300) │■y580■■■│      │■■■■■■■│               │▓▓SOLID BLOCK▓▓▓▓▓▓│
│  [plate]   │      │        │      │       │               │ x=2000,y=560,h=160│
│  [cell1]   │      │        │      │       │               │                   │
│▓▓▓FLOOR▓▓▓▓│      │▓FLOOR▓▓│      │▓FLOOR▓│               │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
└────────────┴──────┴────────┴──────┴───────┴───────────────┴────────────────────┘

Wide pit (300px = 1.49× jump range of 201.5px): must Duplicate bridge from B.
Gap at x=1300 (100px = 0.5× jump range): jumpable practice gap.
Gap at x=1840 (100px): jumpable via step platform at x=1900,y=620.
Rock wall (x=1700, h=200px > jump height 120+80 margin): must Delete from B.
Portal 1 (x=150,y=590): B-room objective (push crate+plate) + Duplicate.
Portal 2 (x=1430,y=590): Delete wall — edit_wall_b1 at x=1700 is 216px away (center check).
Goal block: solid x=2000,y=560,h=160. Step at x=1900,y=620 bridges the 60px climb.
```

### Points Budget

| Event                              | EP Change | Running Total |
|------------------------------------|-----------|---------------|
| Start                              | +30       | 30            |
| Cell #1 (ground, x=430)            | +5        | 35            |
| Portal 1 → B, push_block objective | +25       | 60            |
| Time bonus (within 25 s)           | +10       | 70            |
| Duplicate bridge (skill in B)      | −20       | 50            |
| Clear obstacle reward              | +10       | 60            |
| Portal 1 → A, cross bridge         | —         | 60            |
| Cell #2 (ledge, x=800)             | +5        | 65            |
| Jump practice gap (x=1300, 100px)  | —         | 65            |
| Portal 2 → B                       | —         | 65            |
| Delete wall (skill in B)           | −15       | 50            |
| Clear obstacle reward              | +10       | 60            |
| Portal 2 → A                       | —         | 60            |
| Cell #3 (x=1700)                   | +5        | 65            |
| Step + jump onto goal block        | —         | 65            |
| Collect ship part (Nav Chip)       | +30       | 95            |
| Reach exit, 3 lives left           | +30       | 125           |

**Minimum to finish (no deaths, no time bonus, skip all cells):**
30 + 25 − 20 + 10 − 15 + 10 + 30 = **70 EP** (generous)

**After 1 death (−20 EP, respawns at Portal 2, 2 lives left, +20 at end):**
70 − 20 − 10 = **40 EP** — still completable ✓

### Solvability Check

- Must spend: Duplicate 20 + Delete 15 = **35 EP** total on skills.
- Earns before spending: cell #1 +5, B objective +25 = **+30** → total 60 EP before skills.
- After skills: 60 − 35 + 20 (clear rewards) = **45 EP** remaining.
- Remaining rewards: cells #2 & #3 +10, part +30, 3 lives +30 = **+70** → finish at 115+.
- After 1 death (respawns at Portal 2, 2 lives): 45 − 20 + 10 + 30 + 20 = **85 EP**. ✓

## Level 3 — Europa (Ice Moon)

### Side-View Sketch

```
X=0       X=600  X=1020   X=1350  X=1600 X=1720      X=2100        X=3120
┌─────────┐      ┌────────┐▓wall▓  step  ┌──────────────────────────────────┐
│         │      │        │ ▓▓▓▓   ▓▓▓   │                                  │
│SPAWN ●  │ PIT  │ [p2↕]  │              │ [p3↕]   MONSTER    [cell3]       │
│[p1↕]    │(420) │ [cell1]│              │         (w48,h48)  [part2][EXIT] │
│[crate]  │      │ [part1]│              │                                  │
│[plate]  │      │        │       [cell2]│▓▓▓▓▓▓▓ SOLID SHELF ▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓FLOOR▓▓│←420→ │▓FLOOR▓▓│       ▓FLOOR▓│ x=1720, y=560, h=160             │
└─────────┴──────┴────────┴──────────────┴──────────────────────────────────┘
Y=680 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

World A: Pit (600-1020, w=420), Portal 1 (x=150), Portal 2 (x=1080),
         cell 1 (x=1180), part 1 (x=1260), wall (x=1350), cell 2 (x=1500),
         step (x=1600, y=620), shelf (x=1720, y=560), Portal 3 (x=1780),
         monster (x=2100), cell 3 (x=2350), part 2 (x=2650), exit (x=2950).
World B: crate + plate objective (x=330, x=440),
         Twins: bridge (duplicate, x=600), wall (move, x=1350), monster (delete, x=2100).
```

### Points Budget — Path A (Delete monster in B)

| Event                           | EP Change | Running Total |
|---------------------------------|-----------|---------------|
| Start                           | +30       | 30            |
| Portal → B, push_block objective| +25       | 55            |
| Time bonus (within 25 s)        | +10       | 65            |
| Move door (skill in B)          | −10       | 55            |
| Clear obstacle reward           | +10       | 65            |
| Duplicate bridge (skill in B)   | −20       | 45            |
| Clear obstacle reward           | +10       | 55            |
| Delete monster (skill in B)     | −15       | 40            |
| Clear obstacle reward           | +10       | 50            |
| Portal → A, cross bridge        | —         | 50            |
| Energy cell #1                  | +5        | 55            |
| Collect Thruster 1              | +30       | 85            |
| Pass door, cross monster area   | —         | 85            |
| Energy cell #2                  | +5        | 90            |
| Energy cell #3                  | +5        | 95            |
| Collect Thruster 2              | +30       | 125           |
| Reach exit, 3 lives left        | +30       | 155           |

### Points Budget — Path B (Shield past monster in A)

| Event                           | EP Change | Running Total |
|---------------------------------|-----------|---------------|
| Start                           | +30       | 30            |
| Portal → B, push_block objective| +25       | 55            |
| Time bonus                      | +10       | 65            |
| Move door (skill in B)          | −10       | 55            |
| Clear obstacle reward           | +10       | 65            |
| Duplicate bridge (skill in B)   | −20       | 45            |
| Clear obstacle reward           | +10       | 55            |
| Portal → A, cross bridge        | —         | 55            |
| Energy cell #1                  | +5        | 60            |
| Collect Thruster 1              | +30       | 90            |
| Shield (A, before monster)      | −10       | 80            |
| Energy cell #2                  | +5        | 85            |
| Energy cell #3                  | +5        | 90            |
| Collect Thruster 2              | +30       | 120           |
| Reach exit, 3 lives left        | +30       | 150           |

**Minimum to finish (Delete path, no time bonus, no cells):**
30 + 25 − 10 + 10 − 20 + 10 − 15 + 10 + 30 + 30 = **100 EP** (generous)

**After 1 death (Delete path, no time bonus, no cells):**
100 − 20 + 20 (2 lives) = **100 EP** — still generous ✓

**After 1 death (Shield path, no time bonus, no cells):**
30 + 25 − 10 + 10 − 20 + 10 − 10 + 30 + 30 − 20 + 20 = **95 EP** — still OK ✓

### Solvability Check

- Must spend: Move 10 + Duplicate 20 + Delete 15 = **45 EP** (or 40 with Shield).
- Earns before spending: B objective +25 → total 55 before skills.
- After skills (Delete): 55 − 45 + 30 (clear rewards) = **40 EP** remaining.
- Remaining rewards: 3 cells +15, 2 parts +60, lives +30 = **+105** → finish at 145+.
- After 1 death: 40 − 20 + 15 + 60 + 20 = **115 EP**. ✓ Generous.
- Death makes it *tighter* than Levels 1–2 because skill costs are higher (45 vs 35), but still very beatable.

## Level 4 — Glitch Core (Final)

### Side-View Sketch

```
X=0       X=600  X=1000  X=1600 X=1814 X=1964 X=2150 X=2450 X=2700      X=3200
┌─────────┐      ┌───────┐▓door ┌──────┐      ┌──────┬──────┬─────────────────┐
│SPAWN ●  │ PIT  │[p2↕]  │▓▓▓▓  │glitch│      │[plat]│      │                 │
│[p1↕]    │(400) │MON1   │      │spikes│[p3↕] │spikes│ MON2 │                 │
│[obj 1]  │      │[obj 2]│      │▲▲▲▲▲▲│      │▲▲▲▲▲▲│      │[part] [EXIT]    │
│[cell 1] │      │[cell2]│      │      │      │      │      │▓▓▓ launch gate ▓│
│▓▓FLOOR▓▓│←400→ │▓FLOOR▓│      │▓FLOOR│      │▓▓▓▓▓▓FLOOR▓▓│▓▓▓▓▓▓ (h:140) ▓▓│
└─────────┴──────┴───────┴──────┴──────┴──────┴─────────────┴─────────────────┘
Y=680 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

World A: Pit (600-1000), Mon 1 (x=1250), Door (x=1600), Glitch Spikes (x=1814),
         Upper Plat (x=2100), Spikes 2 (x=2150), Mon 2 (x=2450), Crystal (x=2600), Exit (x=2950).
World B: 2 Objectives (crates/plates at x=300 & x=1400),
         Twins: bridge (duplicate), door (move), mon 1 (delete),
                glitch spikes (delete), spikes 2 (delete), mon 2 (delete).
```

### Points Budget

| Event                                       | EP Change | Running Total |
|---------------------------------------------|-----------|---------------|
| Start                                       | +30       | 30            |
| Energy cell #1                              | +5        | 35            |
| Portal 1 → B, complete Objective 1          | +25       | 60            |
| Time bonus (within 25 s)                    | +10       | 70            |
| Duplicate bridge over pit (skill in B)      | −20       | 50            |
| Clear obstacle reward                       | +10       | 60            |
| Portal 1 → A, cross bridge to Portal 2      | —         | 60            |
| Portal 2 → B, complete Objective 2          | +25       | 85            |
| Move locked door (skill in B)               | −10       | 75            |
| Clear obstacle reward                       | +10       | 85            |
| Energy cell #2                              | +5        | 90            |
| **Decision Point**: Delete vs Bypass        |           |               |
| *Choice: Bypass Mon 1, Delete Spikes 1*     | −15       | 75            |
| Clear obstacle reward                       | +10       | 85            |
| Cross glitch zone to Portal 3               | —         | 85            |
| *Choice: Jump past Spikes 2 using upper plat*| 0        | 85            |
| Energy cell #3                              | +5        | 90            |
| *Choice: Jump past Mon 2 using timing*      | 0         | 90            |
| Collect Ship Part (Core Crystal)            | +30       | 120           |
| Reach launch gate, 3 lives left             | +30       | 150           |

---

### Solvability Check & The "Tight Points" Proof

1. **Why using every skill is impossible (Forced Trade-offs):**
   - Total skill cost if attempting to delete everything:
     $\text{Duplicate Bridge } (20) + \text{Move Door } (10) + \text{Delete Mon 1 } (15) + \text{Delete Spikes 1 } (15) + \text{Delete Spikes 2 } (15) + \text{Delete Mon 2 } (15) = \mathbf{90\text{ EP}}$.
   - Total EP obtainable before the mid-boss zone:
     $30\text{ (start)} + 25\text{ (obj 1)} + 10\text{ (bonus)} + 5\text{ (cell 1)} + 25\text{ (obj 2)} = \mathbf{95\text{ EP}}$.
   - If player spends 90 EP without completing both objectives first, their balance drops to 0, locking them out of mandatory skills (Bridge + Door).
   - Therefore, the player **must decide** which obstacles to remove (Bridge + Door + 1 Spikes) and which to jump past (Monsters 1 & 2).

2. **Solvability after 1 Death (−20 EP):**
   - Start: 30
   - Objective 1: +25 → 55
   - Duplicate Bridge: −20 (+10) → 45
   - Move Door: −10 (+10) → 45
   - **Death on Monster 1**: −20 EP, 2 lives left → **25 EP**.
   - Player respawns at Portal 2 with only 25 EP!
   - They CANNOT afford to delete Monster 1 or Monster 2.
   - Objective 2: +25 → 50 EP.
   - They can afford to delete at most one hazard (Spikes 1: −15 + 10 → 45 EP).
   - They must jump past both monsters and Spikes 2.
   - Part +30, Cell 2 & 3 +10, Lives (2 × 10) +20 → **Finish at 105 EP**.
   - **Result**: Level remains beatable after 1 death, but demands strict EP conservation and platforming precision. ✓

