import sqlite3
import pandas as pd

conn = sqlite3.connect("data/football.db")

stats = pd.read_csv("data/player_stats.csv", encoding="latin-1", sep=";")
stats.to_sql("player_stats", conn, if_exists="replace", index=False)

values = pd.read_csv("data/player_valuations.csv")
values.to_sql("player_values", conn, if_exists="replace", index=False)

players = pd.read_csv("archive (3)/players.csv")[["player_id", "name"]]
players.to_sql("players_bridge", conn, if_exists="replace", index=False)

print("Tables loaded:")
for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'"):
    name = row[0]
    count = conn.execute(f"SELECT COUNT(*) FROM [{name}]").fetchone()[0]
    print(f"  {name}: {count:,} rows")

conn.close()
