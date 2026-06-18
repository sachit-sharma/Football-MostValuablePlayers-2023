import sqlite3
import pandas as pd
import os

os.makedirs("tableau_exports", exist_ok=True)
conn = sqlite3.connect("data/football.db")

# Apply views first
with open("queries.sql") as f:
    conn.executescript(f.read())

views = [
    "v_all_scored",
    "v_value_ranked",
    "v_top5_performers",
    "v_league_summary",
    "v_age_band_summary",
    "v_aggression",
]

for view in views:
    df = pd.read_sql(f"SELECT * FROM {view}", conn)
    path = f"tableau_exports/{view}.csv"
    df.to_csv(path, index=False)
    print(f"  {view}: {len(df)} rows → {path}")

conn.close()
print("\nDone. Connect tableau_exports/ in Tableau Desktop.")
