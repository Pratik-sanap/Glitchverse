# Level Budgets — Rift Runner

All values match `src/logic/config.gd`. Update this doc whenever a level changes.

---

## Level 1 — Moon (Tutorial)

### Side-View Sketch

```
X=0            X=600      X=1000                    X=2400
┌──────────────┐          ┌─────────────────────────────┐
│              │          │                             │
│  SPAWN       │   PIT    │  [spike]                    │
│  ●           │  (gap)   │  ▲▲▲▲                      │
│  ■■■■■■■■■■ │←  400 →│ ■■■ledge■■                   │
│              │          │        ■■■■■■■■■■■■■■■■■■■■│
│              │          │  [cell]  [part]  [EXIT]     │
│  [portal↕]   │          │  ■■■long platform■■■■■■■■■■│
│▓▓▓FLOOR▓▓▓▓▓│          │▓▓▓▓▓FLOOR▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
└──────────────┘          └─────────────────────────────┘
Y=680 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

World B: editBlock-bridge over pit (duplicate), editBlock-spike (delete),
         crate + plate for push_block objective on the upper platform.
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

*(coming next)*

## Level 3 — Europa

*(coming next)*

## Level 4 — Glitch Core

*(coming next)*
