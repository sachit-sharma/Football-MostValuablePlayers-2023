-- Football Player Value Analysis — SQLite Views
-- 2022-23 season | Top 5 European Leagues
-- Valuation anchor: 2023-05-31 (end of season, before summer window)
-- Position rule: primary position = first 2 characters of Pos field
-- GK excluded throughout | Minimum 10 x 90s played

-- ─────────────────────────────────────────────────────────────────
-- 1. v_stats_clean
--    Raw stats filtered: non-GK, ≥10 90s, primary_pos derived
-- ─────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_stats_clean;
CREATE VIEW v_stats_clean AS
SELECT
    Player,
    Squad,
    Comp,
    Pos,
    SUBSTR(Pos, 1, 2)                          AS primary_pos,
    CAST(Age AS INTEGER)                        AS Age,
    CAST("90s" AS REAL)                         AS nineties,
    CAST(Goals AS REAL)                         AS Goals,
    CAST(Assists AS REAL)                       AS Assists,
    CAST(SCA AS REAL)                           AS SCA,
    CAST(GCA AS REAL)                           AS GCA,
    CAST(Tkl AS REAL)                           AS Tkl,
    CAST(Int AS REAL)                           AS Int_,
    CAST(Clr AS REAL)                           AS Clr,
    CAST(Blocks AS REAL)                        AS Blocks,
    CAST(AerWon AS REAL)                        AS AerWon,
    CAST(PasProg AS REAL)                       AS PasProg,
    CAST(Pas3rd AS REAL)                        AS Pas3rd,
    CAST(Fls AS REAL)                           AS Fls,
    CAST(CrdY AS REAL)                          AS CrdY,
    CAST(CrdR AS REAL)                          AS CrdR
FROM player_stats
WHERE
    SUBSTR(Pos, 1, 2) != 'GK'
    AND CAST("90s" AS REAL) >= 10;

-- ─────────────────────────────────────────────────────────────────
-- 2. v_valuations_season
--    One row per player_id: valuation closest to 2023-05-31
--    within the 2022-07-01 – 2023-06-30 season window
-- ─────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_valuations_season;
CREATE VIEW v_valuations_season AS
SELECT
    player_id,
    date          AS valuation_date,
    market_value_in_eur,
    CAST(market_value_in_eur AS REAL) / 1000000.0 AS market_value_eur_M
FROM (
    SELECT
        player_id,
        date,
        market_value_in_eur,
        ROW_NUMBER() OVER (
            PARTITION BY player_id
            ORDER BY ABS(julianday(date) - julianday('2023-05-31'))
        ) AS rn
    FROM player_values
    WHERE date BETWEEN '2022-07-01' AND '2023-06-30'
)
WHERE rn = 1;

-- ─────────────────────────────────────────────────────────────────
-- 3. v_best_player_id
--    For each FBref player name, pick the single best-matching
--    player_id from players_bridge: the one whose closest valuation
--    to 2023-05-31 is nearest. Resolves common-name ambiguity
--    (e.g. "Danilo" matches 8 different player IDs in the bridge).
-- ─────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_best_player_id;
CREATE VIEW v_best_player_id AS
SELECT name, player_id
FROM (
    SELECT
        pb.name,
        pb.player_id,
        MIN(ABS(julianday(pv.date) - julianday('2023-05-31'))) AS best_dist,
        ROW_NUMBER() OVER (
            PARTITION BY pb.name
            ORDER BY MIN(ABS(julianday(pv.date) - julianday('2023-05-31')))
        ) AS rn
    FROM players_bridge pb
    JOIN player_values pv ON pb.player_id = pv.player_id
    WHERE pv.date BETWEEN '2022-07-01' AND '2023-06-30'
    GROUP BY pb.name, pb.player_id
)
WHERE rn = 1;

-- ─────────────────────────────────────────────────────────────────
-- 4. v_joined
--    Stats → v_best_player_id (one player_id per name) → valuation
--    Unmatched players kept (NULL valuation) — report separately
-- ─────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_joined;
CREATE VIEW v_joined AS
SELECT
    s.Player,
    s.Squad,
    s.Comp,
    s.Pos,
    s.primary_pos,
    s.Age,
    s.nineties,
    s.Goals,
    s.Assists,
    s.SCA,
    s.GCA,
    s.Tkl,
    s.Int_,
    s.Clr,
    s.Blocks,
    s.AerWon,
    s.PasProg,
    s.Pas3rd,
    s.Fls,
    s.CrdY,
    s.CrdR,
    bpi.player_id,
    vs.valuation_date,
    vs.market_value_in_eur,
    vs.market_value_eur_M
FROM v_stats_clean s
LEFT JOIN v_best_player_id bpi ON LOWER(TRIM(s.Player)) = LOWER(TRIM(bpi.name))
LEFT JOIN v_valuations_season vs ON bpi.player_id = vs.player_id;

-- ─────────────────────────────────────────────────────────────────
-- 4. v_scored_fw  — Forwards
--    NOTE: In this FBref CSV, Goals is a raw season total while
--    Assists, SCA, GCA are already per-90. Formula adapts accordingly.
--    attacking_score = Goals/90s + Assists + SCA*0.3 + GCA*0.5
-- ─────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_scored_fw;
CREATE VIEW v_scored_fw AS
SELECT
    Player, Squad, Comp, Pos, primary_pos, Age, nineties,
    Goals, Assists, SCA, GCA,
    market_value_in_eur, market_value_eur_M, valuation_date,
    'FW'                                                             AS pos_group,
    Goals / nineties + Assists + SCA * 0.3 + GCA * 0.5             AS perf_score,
    CASE
        WHEN market_value_eur_M > 0
        THEN (Goals / nineties + Assists + SCA * 0.3 + GCA * 0.5) / market_value_eur_M
        ELSE NULL
    END                                                              AS value_score
FROM v_joined
WHERE primary_pos = 'FW';

-- ─────────────────────────────────────────────────────────────────
-- 5. v_scored_mf  — Midfielders
--    Assists, PasProg, Pas3rd, SCA, Tkl, Int are all per-90 in source.
--    midfield_score = Assists + PasProg + Pas3rd + SCA*0.3 + (Tkl+Int)*0.2
-- ─────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_scored_mf;
CREATE VIEW v_scored_mf AS
SELECT
    Player, Squad, Comp, Pos, primary_pos, Age, nineties,
    Assists, PasProg, Pas3rd, SCA, Tkl, Int_,
    market_value_in_eur, market_value_eur_M, valuation_date,
    'MF'                                                                     AS pos_group,
    Assists + PasProg + Pas3rd + SCA * 0.3 + (Tkl + Int_) * 0.2            AS perf_score,
    CASE
        WHEN market_value_eur_M > 0
        THEN (Assists + PasProg + Pas3rd + SCA * 0.3 + (Tkl + Int_) * 0.2) / market_value_eur_M
        ELSE NULL
    END                                                                       AS value_score
FROM v_joined
WHERE primary_pos = 'MF';

-- ─────────────────────────────────────────────────────────────────
-- 6. v_scored_df  — Defenders
--    Tkl, Int, Clr, Blocks, AerWon are all per-90 in source.
--    defensive_score = Tkl + Int + Clr + Blocks + AerWon
-- ─────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_scored_df;
CREATE VIEW v_scored_df AS
SELECT
    Player, Squad, Comp, Pos, primary_pos, Age, nineties,
    Tkl, Int_, Clr, Blocks, AerWon,
    market_value_in_eur, market_value_eur_M, valuation_date,
    'DF'                                        AS pos_group,
    Tkl + Int_ + Clr + Blocks + AerWon         AS perf_score,
    CASE
        WHEN market_value_eur_M > 0
        THEN (Tkl + Int_ + Clr + Blocks + AerWon) / market_value_eur_M
        ELSE NULL
    END                                          AS value_score
FROM v_joined
WHERE primary_pos = 'DF';

-- ─────────────────────────────────────────────────────────────────
-- 7. v_all_scored  — Union of all three position groups
-- ─────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_all_scored;
CREATE VIEW v_all_scored AS
SELECT Player, Squad, Comp, Pos, primary_pos, Age, nineties,
       market_value_in_eur, market_value_eur_M, valuation_date,
       pos_group, perf_score, value_score
FROM v_scored_fw
UNION ALL
SELECT Player, Squad, Comp, Pos, primary_pos, Age, nineties,
       market_value_in_eur, market_value_eur_M, valuation_date,
       pos_group, perf_score, value_score
FROM v_scored_mf
UNION ALL
SELECT Player, Squad, Comp, Pos, primary_pos, Age, nineties,
       market_value_in_eur, market_value_eur_M, valuation_date,
       pos_group, perf_score, value_score
FROM v_scored_df;

-- ─────────────────────────────────────────────────────────────────
-- 8. v_value_ranked
--    Rank within position group by value_score (only valued players)
-- ─────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_value_ranked;
CREATE VIEW v_value_ranked AS
SELECT
    *,
    RANK() OVER (
        PARTITION BY pos_group
        ORDER BY value_score DESC
    ) AS value_rank
FROM v_all_scored
WHERE value_score IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────
-- 9. v_league_summary
--    Avg perf_score, avg value_score, avg market value per league × position
-- ─────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_league_summary;
CREATE VIEW v_league_summary AS
SELECT
    Comp                            AS league,
    pos_group,
    COUNT(*)                        AS player_count,
    ROUND(AVG(perf_score), 3)       AS avg_perf_score,
    ROUND(AVG(value_score), 4)      AS avg_value_score,
    ROUND(AVG(market_value_eur_M), 2) AS avg_market_value_eur_M
FROM v_all_scored
WHERE value_score IS NOT NULL
GROUP BY Comp, pos_group
ORDER BY pos_group, avg_value_score DESC;

-- ─────────────────────────────────────────────────────────────────
-- 10. v_age_band_summary
--     Age bands: U21 | 21-25 | 26-29 | 30+
-- ─────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_age_band_summary;
CREATE VIEW v_age_band_summary AS
SELECT
    CASE
        WHEN Age < 21            THEN 'U21'
        WHEN Age BETWEEN 21 AND 25 THEN '21-25'
        WHEN Age BETWEEN 26 AND 29 THEN '26-29'
        ELSE '30+'
    END                             AS age_band,
    pos_group,
    COUNT(*)                        AS player_count,
    ROUND(AVG(perf_score), 3)       AS avg_perf_score,
    ROUND(AVG(value_score), 4)      AS avg_value_score,
    ROUND(AVG(market_value_eur_M), 2) AS avg_market_value_eur_M
FROM v_all_scored
WHERE value_score IS NOT NULL
GROUP BY age_band, pos_group
ORDER BY pos_group,
    CASE age_band
        WHEN 'U21'   THEN 1
        WHEN '21-25' THEN 2
        WHEN '26-29' THEN 3
        ELSE 4
    END;

-- ─────────────────────────────────────────────────────────────────
-- 11. v_aggression
--     Fls, CrdY, CrdR are already per-90 in the FBref source CSV.
--     Use directly without dividing by nineties again.
-- ─────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_aggression;
CREATE VIEW v_aggression AS
SELECT
    Player,
    Squad,
    Comp,
    Pos,
    primary_pos,
    Age,
    nineties,
    Fls,
    CrdY,
    CrdR,
    ROUND(Fls, 3)                    AS fouls_per90,
    ROUND(CrdY + CrdR * 2, 3)        AS card_rate_per90
FROM v_stats_clean
ORDER BY fouls_per90 DESC;

-- ─────────────────────────────────────────────────────────────────
-- 12. v_top5_performers
--     Top 5 players by raw perf_score within each position group,
--     plus the average market value of those 5 per position.
--     All players included (with or without valuation).
-- ─────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_top5_performers;
CREATE VIEW v_top5_performers AS
SELECT
    pos_group,
    Player,
    Squad,
    Comp,
    Age,
    nineties,
    perf_score,
    perf_rank,
    market_value_eur_M,
    AVG(market_value_eur_M) OVER (PARTITION BY pos_group) AS avg_market_value_eur_M_top5
FROM (
    SELECT
        pos_group,
        Player,
        Squad,
        Comp,
        Age,
        nineties,
        perf_score,
        market_value_eur_M,
        RANK() OVER (PARTITION BY pos_group ORDER BY perf_score DESC) AS perf_rank
    FROM v_all_scored
)
WHERE perf_rank <= 5
ORDER BY pos_group, perf_rank;

-- ─────────────────────────────────────────────────────────────────
-- Diagnostic queries (run manually to check match rate)
-- ─────────────────────────────────────────────────────────────────

-- Match rate:
-- SELECT
--     COUNT(*) AS total_clean,
--     SUM(CASE WHEN player_id IS NOT NULL THEN 1 ELSE 0 END) AS matched,
--     SUM(CASE WHEN market_value_eur_M IS NOT NULL THEN 1 ELSE 0 END) AS with_valuation
-- FROM v_joined;
