# Level Budgets — Rift Runner

All values match `src/logic/config.gd`. Update this doc whenever a level changes.

---

## Level 1 — Moon (Tutorial)

### Side-View Sketch

```
X=0            X=600      X=1000       X=1600               X=2400
┌──────────────┐          ┌────────────┬────────────────────────┐
│ SPAWN        │   PIT    │            │                        │
│ ●            │  (gap)   │ [spike]    │                        │
│ [portal↕]    │          │ ▲▲▲▲▲▲▲▲▲  │ [cell]  [part]  [EXIT] │
│ [crate]      │          │ (360 wide) │                        │
│ [plate] [cell│          │            │ ▓▓▓ raised shelf ▓▓▓▓▓ │
│▓▓▓FLOOR▓▓▓▓▓▓│←  400 →  │▓▓▓FLOOR▓▓▓▓│▓▓▓▓▓▓ (h:140) ▓▓▓▓▓▓▓▓▓│
└──────────────┴──────────┴────────────┴────────────────────────┘
Y=680 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

World B: editBlock-bridge over pit (duplicate, twin: pit_a1),
         editBlock-spike on ground (delete, twin: spike_a1),
         crate + plate for push_block objective on ground before portal.
```

### Points Budget

| Event                        | EP Change | Running Total |
|------------------------------|-----------|---------------|
| Start                        | +30       | 30            |
| Energy cell #1 (upper plat)  | +5        | 35            |
| Portal → B, complete push_block objective | +25 | 60    |
| Time bonus (within 30 s)     | +10       | 70            |
| Delete spike (skill in B)    | −15       | 55            |
| Clear obstacle reward        | +10       | 65            |
| Duplicate bridge (skill in B)| −20       | 45            |
| Clear obstacle reward        | +10       | 55            |
| Portal → A, cross bridge     | —         | 55            |
| Energy cell #2               | +5        | 60            |
| Collect ship part (Fuel Cell)| +30       | 90            |
| Reach exit, 3 lives left     | +30       | 120           |

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
X=0          X=500  X=700    X=1100  X=1300       X=1800  X=2000     X=2800
┌────────────┐      ┌────────┐      ┌─────────────┐      ┌──────────────┐
│            │      │        │      │             │      │              │
│  SPAWN ●   │ PIT  │ ledge  │ PIT  │ [wall]▓▓▓▓ │      │              │
│            │(wide)│[cell]  │(jump)│ ▓▓▓▓▓▓▓▓▓▓ │      │ [part] [EXIT]│
│ [portal↕]  │ 200  │        │ 200  │ [cell]      │ gap  │              │
│■■■■■■■■■■■│      │■■■■■■■■│      │■■■■■■■■■■■■│      │■■■■■■■■■■■■■│
│▓▓▓FLOOR▓▓▓│      │▓FLOOR▓▓│      │▓▓▓FLOOR▓▓▓▓│      │▓▓▓FLOOR▓▓▓▓▓│
└────────────┘      └────────┘      └─────────────┘      └──────────────┘

B room: Move block onto target pad (+25), Duplicate bridge over wide pit (-20),
        Delete wall block (-15). 3 energy cells scattered.
```

### Points Budget

| Event                          | EP Change | Running Total |
|--------------------------------|-----------|---------------|
| Start                          | +30       | 30            |
| Energy cell #1 (upper plat)    | +5        | 35            |
| Portal → B, complete push_block| +25       | 60            |
| Time bonus (within 25 s)       | +10       | 70            |
| Duplicate bridge (skill in B)  | −20       | 50            |
| Clear obstacle reward          | +10       | 60            |
| Delete wall (skill in B)       | −15       | 45            |
| Clear obstacle reward          | +10       | 55            |
| Portal → A, cross bridge       | —         | 55            |
| Energy cell #2                 | +5        | 60            |
| Energy cell #3                 | +5        | 65            |
| Collect ship part (Nav Chip)   | +30       | 95            |
| Reach exit, 3 lives left       | +30       | 125           |

**Minimum to finish (no deaths, no time bonus, skip all cells):**
30 + 25 − 20 + 10 − 15 + 10 + 30 = **70 EP** (generous)

**After 1 death (−20 EP, 2 lives left, +20 at end instead of +30):**
70 − 20 − 10 = **40 EP** — still completable ✓

### Solvability Check

- Player starts with 30 EP.
- Must spend: Duplicate 20 + Delete 15 = **35 EP** on skills.
- Earns before spending: B objective +25 = **+25** → total 55 EP before skills.
- After skills: 55 − 35 + 20 (clear rewards) = **40 EP** remaining.
- Remaining rewards: 3 cells +15, part +30, lives +30 = **+75** → finish at 115+.
- Even after 1 death: 40 − 20 + 15 + 30 + 20 = **85 EP**. ✓ Generous.

## Level 3 — Europa (Ice Moon)

### Side-View Sketch

```
X=0       X=600  X=900    X=1500  X=1600         X=2200          X=3000
┌─────────┐      ┌────────┐▓door▓ ┌──────────────────────────────────┐
│         │      │        │ ▓▓▓▓  │                                  │
│SPAWN ●  │ PIT  │ [cell] │       │  MONSTER →←    [cell]            │
│         │(300) │ [part1]│       │                [part2] [EXIT]    │
│[portal↕]│      │        │       │  [cell]  ■■■upper plat■■■■■■■■  │
│■■■■■■■■■│      │■■■■■■■■│       │■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■│
│▓▓FLOOR▓▓│      │▓FLOOR▓▓│       │▓▓▓▓▓▓▓▓▓▓▓FLOOR▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
└─────────┘      └────────┘       └──────────────────────────────────┘

B room (portal on upper-left ledge):
  Objective: push crate onto plate (+25).
  Skills: Move door editBlock (-10), Duplicate bridge over pit (-20),
          Delete monster editBlock (-15) OR return to A and Shield (-10).
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

## Level 4 — Glitch Core

*(coming next)*
