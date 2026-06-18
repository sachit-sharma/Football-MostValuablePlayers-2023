# %%
import sqlite3
import pandas as pd

conn = sqlite3.connect("data/football.db")


print(pd.read_sql("PRAGMA table_info(player_stats)", conn))
print(pd.read_sql("PRAGMA table_info(player_values)", conn))

conn.close()
