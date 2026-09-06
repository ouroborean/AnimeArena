# Anime Arena Discord Bot

A Discord bot that gives your players a reference desk for the game — character/ability
lookups, live Nexus standings, server status — plus a few fun gadgets. Built with
`discord.py` (slash commands), designed to run on the **same Google Cloud VM as the game
server**, reading the game's data files directly and querying the server's WebSocket gateway.

## Commands

| Command | What it does |
| --- | --- |
| `/ability <name>` | Look up a skill — cost, cooldown, classes, full description, image. Fuzzy + autocomplete. |
| `/character <name>` | A character's bio, universe, energy colours, and full kit. |
| `/glossary <term>` | Define a keyword/mechanic (Invulnerable, Channel, Affliction…). |
| `/nexus [universe]` | Live Nexus standings (community AP leaderboard), optionally filtered by universe. |
| `/status` | Is the game server online? Latency + maintenance state. |
| `/ladder` | Top ranked players by rating. |
| `/roll [dice]` | Dice roller — `2d6+3`, `d100`, default `1d20`. |
| `/coinflip` | A fair coin (nod to the who-goes-first coin). |
| `/random-character` | Picks a random playable character and shows its kit. |

`/ability`, `/character`, `/nexus`, `/status`, `/ladder` come from live game data; the rest are self-contained.

## How it's wired

```
Discord ──slash cmd──▶ bot.py ──▶ cogs/{references,nexus,gadgets}.py
                                     │
                 references ─────────┤─▶ data_store.py ─▶ game JSON (abilities_data.json,
                 (ability/char/       │                    ability_info.json, roster.json,
                  glossary)           │                    char_index.json, skill_glossary.json)
                                      │
                 nexus/status/ladder ─┴─▶ gateway.py ─ws JSON─▶ game server :5695
```

- **Ability data** is read straight from the game's files (fuzzy-matched with `rapidfuzz`,
  or the stdlib `difflib` if it isn't installed). Edits to abilities show up on the next
  lookup — no bot restart needed.
- **Nexus / status / ladder** are read live over the server's WebSocket JSON gateway. Those
  message types (`nexus_state`, `server_status`, `ping`, `ladder`) require no login.

## Prerequisites

- Python **3.10+**
- A Discord account with permission to add a bot to your server
- The game checkout present on the machine (this folder lives inside it)

---

## 1. Create the Discord bot (you do this — it involves a secret token)

1. Go to the **[Discord Developer Portal](https://discord.com/developers/applications)** → **New Application**, name it.
2. **Bot** tab → **Reset Token** → **Copy**. This is your `DISCORD_TOKEN` (keep it secret).
3. Under **Privileged Gateway Intents**, you can leave everything **off** — this bot only uses slash commands.
4. **Installation** (or **OAuth2 → URL Generator**): scopes `bot` + `applications.commands`;
   bot permission **Send Messages** (and **Embed Links**). Open the generated URL to invite the bot to your server.

## 2. Configure

```bash
cd discord-bot
cp .env.example .env
chmod 600 .env
# edit .env: paste DISCORD_TOKEN, and set DISCORD_GUILD_ID to your server's ID for instant commands
```

Enable **Developer Mode** in Discord (Settings → Advanced), then right-click your server →
**Copy Server ID** for `DISCORD_GUILD_ID` (optional but makes commands appear immediately).

## 3. Verify the data (no token needed)

```bash
python selftest.py
```

This loads the game data and runs sample lookups — confirm it prints `DONE — 0 FAIL(s)`
and that `AA_GAME_DIR` points at your game checkout. If files aren't found, set `AA_GAME_DIR`
in `.env` to the game's root folder.

## 4. Run locally

```bash
python -m venv venv
# Windows: venv\Scripts\activate    macOS/Linux: source venv/bin/activate
pip install -r requirements.txt
# load the .env into your shell (or use a tool like `dotenv`), then:
python bot.py
```

On startup it logs how many abilities/characters it loaded and how many commands it synced.

---

## 5. Deploy on your Google Cloud VM (systemd)

Run these on the VM (adjust the user and paths to match yours; the unit file assumes a user
`animearena` and the bot at `/opt/animearena/discord-bot`).

```bash
# put the bot next to the game (this folder is already inside the game repo):
sudo mkdir -p /opt/animearena
# ...copy your game checkout to /opt/animearena so /opt/animearena/discord-bot exists...

cd /opt/animearena/discord-bot
python3 -m venv venv
./venv/bin/pip install -r requirements.txt

cp .env.example .env && chmod 600 .env
nano .env          # paste DISCORD_TOKEN; set AA_GAME_DIR=/opt/animearena if needed

# quick check before installing the service:
AA_GAME_DIR=/opt/animearena ./venv/bin/python selftest.py

# install + start the service:
sudo cp animearena-bot.service /etc/systemd/system/
sudo nano /etc/systemd/system/animearena-bot.service   # fix User/paths if they differ
sudo systemctl daemon-reload
sudo systemctl enable --now animearena-bot

# watch it come up:
journalctl -u animearena-bot -f
```

If the bot runs on a **different** machine than the game server, also set in `.env`:
`AA_GATEWAY_URL=wss://your-game-domain/...` (the same gateway endpoint your web client uses).

### Firewall / networking
Nothing inbound is required — the bot makes only **outbound** connections (to Discord, and to
the gateway on `localhost:5695`). No ports need opening for the bot itself.

## Updating

```bash
cd /opt/animearena/discord-bot
git pull                              # or copy new files over
./venv/bin/pip install -r requirements.txt   # only if deps changed
sudo systemctl restart animearena-bot
```

Ability/character/glossary data reloads on each lookup, so game-data changes need no restart —
only bot **code** changes do.

## Adding features

Each area is a cog in `cogs/`. To add a gadget, drop a method in `cogs/gadgets.py`:

```python
@app_commands.command(name="tip", description="A random gameplay tip.")
async def tip(self, interaction: discord.Interaction):
    await interaction.response.send_message("…")
```

It's picked up automatically on the next start (and synced to your guild instantly if
`DISCORD_GUILD_ID` is set).

## Config reference (env vars)

| Var | Required | Default | Purpose |
| --- | --- | --- | --- |
| `DISCORD_TOKEN` | ✅ | — | Bot token (secret). |
| `DISCORD_GUILD_ID` | | (global) | Sync commands to one server instantly. |
| `AA_GAME_DIR` | | the game repo containing this folder | Where the game data files live. |
| `AA_GATEWAY_URL` | | `ws://localhost:5695` | Game server's WebSocket JSON gateway. |
| `AA_ASSET_BASE_URL` | | (off) | Host serving `/assets/` — enables images in embeds. |
| `AA_ASSET_VERSION` | | (none) | Cache-buster appended to asset URLs (match the client's `ASSET_VERSION`). |
