# Rift Runner — Level Budgets & Solvability

## Extended Tile Legend (Contract + Extensions)

| Char | Meaning        | Notes                           |
|------|----------------|---------------------------------|
| `#`  | Wall           | Impassable                      |
| `.`  | Floor          | Walkable                        |
| `P`  | Player start   | Only in worldA, exactly one     |
| `O`  | Portal         | Switches dimensions (free)      |
| `c`  | Energy cell    | +5 EP pickup                    |
| `S`  | Spike          | Fatal on contact                |
| `F`  | Ship part      | Required to collect             |
| `X`  | Exit           | Level clear (needs all parts)   |
| `G`  | Gap            | Fatal to walk into              |
| `M`  | Monster        | Patrols, fatal on contact       |
| `B`  | Block/crate    | Pushable in B puzzle            |
| `T`  | Target         | Puzzle target tile              |
| `D`  | Locked door    | Opens via pressure plate        |
| `_`  | Pressure plate | Needs weight to activate        |
| `~`  | Glitch tile    | Fake floor, fatal if stepped on |

## Object `world` field

Each object in the `objects` array includes `"world": "A"` or `"world": "B"` to indicate which dimension it belongs to.

## Position & Grid Format

- `pos`: `{"x": col, "y": row}` — 0-indexed from top-left
- `gridSize`: `{"width": w, "height": h}`
- `portals`: `{"world": "A", "x": col, "y": row}` — flat keys, no nested pos

---

## Level 1 — Moon (Tutorial)

### Grid Sketch

**Dimension A (10×7):**
```
##########
#P..c.S.F#     P=player  c=cell  S=spike  F=part
#........#
####.#####     gap at col 4 connects rooms
#........#
#O......X#     O=portal  X=exit
##########
```

**Dimension B (10×7):**
```
##########
#O.......#     O=portal (B entry)
#........#
####.#####     same wall layout as A
#........#
#...B.T..#     B=pushblock  T=target
##########
```
Spike twin block (object only, no tile char) at [6,1] in B.

### Solution Path

1. **A**: Start at P[1,1], go right to c[4,1] → pick up energy cell (+5 EP)
2. **A**: Navigate down through gap at [4,3] to portal O[1,5]
3. **Portal**: Switch to B → appear at [1,5] in B
4. **B Puzzle**: Push block B[4,5] right twice onto target T[6,5] → **Puzzle solved!** (+25 EP)
5. **B**: Navigate up through gap, use **Delete** on spike twin at [6,1] (−15 EP, +10 EP obstacle clear)
6. **B**: Go to portal O[1,1] → switch back to A at [1,1]
7. **A**: Path is clear! Go right to F[8,1] → pick up ship part (+30 EP)
8. **A**: Navigate down through gap to X[8,5] → **Level Clear!**

### Points Budget

| Event                          | EP Change | Running Total |
|--------------------------------|-----------|---------------|
| Level start                    | +30       | 30            |
| Pick up energy cell            | +5        | 35            |
| Solve B puzzle (within limit)  | +25 +10   | 70            |
| Delete spike (−15) + clear (+10)| −5       | 65            |
| Collect ship part              | +30       | 95            |
| Level clear (3 lives × 10)    | +30       | **125**       |

### Solvability Check

| Scenario                        | EP Available | EP Needed | Result  |
|---------------------------------|-------------|-----------|---------|
| **Perfect run** (no deaths)     | 30 + 40 = 70| Delete 15 | 55 left ✅ |
| **One death** (−20 EP, −1 life) | 30 − 20 + 40 = 50 | Delete 15 | 35 left ✅ |
| **Two deaths** (−40 EP)         | 30 − 40 + 40 = 30 | Delete 15 | 15 left ✅ |

> **Verdict: GENEROUS.** The player can die twice and still complete the level comfortably. Correct for a tutorial.

---

## Level 2 — Mars
*(To be drafted)*

## Level 3 — Europa
*(To be drafted)*

## Level 4 — Glitch Core
*(To be drafted)*
