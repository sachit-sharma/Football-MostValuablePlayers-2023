# Tableau Dashboard Specification
## Football Player Value Analysis — Big 5 European Leagues 2022-23

---

## 1. Getting the Data into Tableau

### Step 1 — Export CSVs from SQLite

Run the following Python script from the project root to export all views as CSV files into a `tableau_exports/` folder:

```python
import sqlite3, pandas as pd, os

os.makedirs("tableau_exports", exist_ok=True)
conn = sqlite3.connect("data/football.db")

exports = [
    "v_all_scored",
    "v_value_ranked",
    "v_top5_performers",
    "v_league_summary",
    "v_age_band_summary",
    "v_aggression",
]

for view in exports:
    df = pd.read_sql(f"SELECT * FROM {view}", conn)
    df.to_csv(f"tableau_exports/{view}.csv", index=False)
    print(f"Exported {view}: {len(df)} rows")

conn.close()
```

### Step 2 — Connect in Tableau Desktop

1. Open Tableau Desktop → **Connect → Text file**
2. Navigate to `tableau_exports/` and select **`v_all_scored.csv`** as the primary source
3. Drag additional CSVs into the canvas and join them:

| Left table | Right table | Join key | Join type |
|---|---|---|---|
| v_all_scored | v_aggression | Player + Squad | Left |
| v_all_scored | v_top5_performers | Player + Squad | Left |

> **Tip:** Use a **Union** instead of a join only if you want a single flat table. The join approach above lets you blend data per sheet without duplicating rows.

### Step 3 — Aliases & Column Tidying (in Tableau)

- Rename `pos_group` → `Position Group`
- Rename `market_value_eur_M` → `Market Value (€M)`
- Rename `perf_score` → `Performance Score`
- Rename `value_score` → `Value Score (Perf/€M)`
- Rename `fouls_per90` → `Fouls per 90`
- Rename `card_rate_per90` → `Card Rate per 90`
- Set `Age`, `nineties` as **Measures** (Tableau may classify them as dimensions)
- Set `Comp`, `Squad`, `Player`, `pos_group` as **Dimensions**

---

## 2. Dashboard Architecture

Build **one Tableau workbook** with **5 sheets** assembled into **2 dashboards**.

---

## 3. Sheet Specifications

### Sheet 1 — Top Value Players (Table)

**Purpose:** Show the top 10 best-value players per position group.

**Data source:** `v_value_ranked`

**Chart type:** Highlight Table / Text Table

**Rows:** Player, Squad, Comp, Age, nineties  
**Columns:** pos_group (filter to one at a time via parameter)  
**Values shown:** perf_score, market_value_eur_M, value_score, value_rank

**Filters:**
- Position Group (single-value dropdown, default = FW)
- Min Market Value €M (slider, range 0–200, default = 1)

**Conditional formatting:**
- value_score: colour scale green (high) → red (low)
- market_value_eur_M: colour scale white → blue (higher value)

**Sort:** value_rank ASC

---

### Sheet 2 — Performance vs Market Value (Scatter)

**Purpose:** Show whether expensive players actually perform better.

**Data source:** `v_all_scored`

**Chart type:** Scatter plot

**X-axis:** `market_value_eur_M` (log scale recommended — distribution is right-skewed)  
**Y-axis:** `perf_score`  
**Colour:** `Comp` (league)  
**Shape:** `pos_group`  
**Label:** Player (show on hover only — use tooltip)  
**Size:** `nineties` (more 90s = larger dot)

**Reference lines:**
- Add average lines for both axes (Analytics pane → Average Line)

**Filters:**
- Position Group (multi-select checkbox)
- League / Comp (multi-select checkbox)
- Min nineties (slider, default = 10)

**Tooltip:**
```
[Player] | [Squad] | [Comp]
Age: [Age]  |  90s played: [nineties]
Perf Score: [perf_score]
Market Value: €[market_value_eur_M]M
Value Score: [value_score]
```

---

### Sheet 3 — League Comparison (Bar Chart)

**Purpose:** Compare average performance and value across leagues.

**Data source:** `v_league_summary`

**Chart type:** Side-by-side bar chart (grouped)

**Rows:** `league` (Comp)  
**Columns:** `avg_value_score` (primary axis), `avg_perf_score` (secondary axis)  
**Colour:** `pos_group`

**Alternative layout:** Use a dual-axis bar — one axis for avg_perf_score, second axis for avg_value_score, synced. Makes cross-league gaps visible.

**Filters:** Position Group (all selected by default)

**Annotations:** Add a reference band on avg_value_score for the all-league average line.

---

### Sheet 4 — Age Curve (Line Chart)

**Purpose:** Show how performance and market value change across age bands.

**Data source:** `v_age_band_summary`

**Chart type:** Line chart with dual axis

**X-axis:** `age_band` (ordered: U21, 21-25, 26-29, 30+)  
**Y-axis (left):** `avg_perf_score`  
**Y-axis (right):** `avg_market_value_eur_M`  
**Colour:** `pos_group`

**Marks:** Circle markers on each point, lines connecting them

**Filters:** Position Group (multi-select)

---

### Sheet 5 — Aggression & Discipline (Scatter)

**Purpose:** Identify the most reckless players and whether aggression correlates with position.

**Data source:** `v_aggression`

**Chart type:** Scatter plot

**X-axis:** `fouls_per90`  
**Y-axis:** `card_rate_per90`  
**Colour:** `pos_group`  
**Size:** Fixed (small)  
**Label:** Player (tooltip only)

**Reference lines:**
- Vertical reference line at median fouls_per90
- Horizontal reference line at median card_rate_per90
- This creates 4 quadrants: High foul + High card = most dangerous; Low foul + Low card = disciplined

**Quadrant labels (add as annotations):**
- Top-right: "High Risk"
- Bottom-right: "Aggressive but Controlled"
- Top-left: "Card-prone"
- Bottom-left: "Clean"

**Filters:** Position Group, League

---

## 4. Dashboard Layouts

### Dashboard 1 — "Player Value Explorer"

**Size:** 1400 × 900 px (Desktop)

**Layout:**

```
┌────────────────────────────────────────────────┐
│  TITLE: Football Player Value Analysis 2022-23  │
│  Subtitle: Top 5 European Leagues               │
├──────────────────┬─────────────────────────────┤
│                  │                             │
│  Sheet 1         │  Sheet 2                    │
│  Top Value       │  Performance vs             │
│  Players Table   │  Market Value Scatter       │
│  (40% width)     │  (60% width)                │
│                  │                             │
├──────────────────┴─────────────────────────────┤
│  Sheet 3 — League Comparison Bar Chart          │
│  (full width, 30% height)                       │
├─────────────────────────────────────────────────┤
│  GLOBAL FILTERS (right panel):                  │
│  • Position Group                               │
│  • League                                       │
│  • Min Market Value                             │
│  • Min 90s played                               │
└─────────────────────────────────────────────────┘
```

**Global filter action:** Set filters on Sheet 1 and Sheet 2 to respond to the same filter controls using **Dashboard Actions → Filter**.

---

### Dashboard 2 — "Age & Aggression"

**Size:** 1400 × 900 px (Desktop)

**Layout:**

```
┌──────────────────────────────────────────────────┐
│  TITLE: Age Curves & Discipline Breakdown         │
├─────────────────────┬────────────────────────────┤
│                     │                            │
│  Sheet 4            │  Sheet 5                   │
│  Age Curves         │  Aggression Scatter        │
│  (50% width)        │  (50% width)               │
│                     │                            │
├─────────────────────┴────────────────────────────┤
│  FILTER: Position Group (applies to both sheets) │
└──────────────────────────────────────────────────┘
```

---

## 5. Calculated Fields to Create in Tableau

These mirror the SQL views but give you flexibility for ad-hoc analysis directly in Tableau.

```
// FW Performance Score (for cross-check)
IF [pos_group] = "FW"
THEN [Goals] / [nineties] + [Assists] + [SCA] * 0.3 + [GCA] * 0.5
END

// MF Performance Score
IF [pos_group] = "MF"
THEN [Assists] + [PasProg] + [Pas3rd] + [SCA] * 0.3 + ([Tkl] + [Int_]) * 0.2
END

// DF Performance Score
IF [pos_group] = "DF"
THEN [Tkl] + [Int_] + [Clr] + [Blocks] + [AerWon]
END

// Value Score
[perf_score] / [market_value_eur_M]

// Age Band
IF [Age] < 21 THEN "U21"
ELSEIF [Age] <= 25 THEN "21-25"
ELSEIF [Age] <= 29 THEN "26-29"
ELSE "30+"
END
```

---

## 6. Parameters to Create

| Parameter name | Type | Values | Used in |
|---|---|---|---|
| Select Position | String | FW, MF, DF, All | Sheet 1 filter |
| Min Market Value (€M) | Float | 0–200, step 1 | Sheet 1 & 2 |
| Min 90s Played | Float | 10–38, step 1 | Sheet 2 |

---

## 7. Key Design Decisions

- **No cross-position ranking** — perf_score is not comparable across FW/MF/DF because formulas use completely different inputs. Always filter or colour by pos_group.
- **Log scale on market value axis** — the distribution is right-skewed (a few players at €100M+, most under €20M). Log scale prevents Mbappe/Bellingham from compressing everyone else.
- **≥€1M market value filter** — players valued under €1M inflate value_score dramatically (dividing by near-zero). Apply the 1M floor filter by default; let users remove it to explore.
- **NULL valuations** — ~12% of players could not be matched to Transfermarkt data. These have NULL market_value_eur_M and will appear in perf_score sheets but drop out of value_score sheets automatically. Tableau will show them as blank in value fields — this is intentional.
