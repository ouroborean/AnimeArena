# Local testing (server + web client)

Run the real Godot server and the web client together on your machine. The client speaks
JSON-over-WebSocket to the server's gateway on **`ws://localhost:5695`**; there is no
login-screen server field, but the client picks the gateway automatically (see below).

## Quick start

```powershell
.\run-local.ps1
```

This launches two windows — the **Godot headless server** (gateway on `ws://localhost:5695`)
and a **static file server rooted at the repo** — then opens
`http://localhost:8777/webclient/app/index.html`.

Options: `-WebPort 9000`, `-Godot "C:\path\to\godot.exe"`, `-NoServer` (web only, if Godot is
already running), `-NoBrowser`. (`run-local.ps1` is git-ignored, like the other `*.ps1` dev
scripts — it lives only on your machine.)

## Or run the two pieces by hand

```powershell
# 1. Server — boots root.tscn -> headless branch -> gateway on ws://localhost:5695
godot --headless --path .

# 2. Web client — serve from the REPO ROOT (one origin for both /webclient/app and /assets)
python -m http.server 8777 --bind 127.0.0.1 --directory .
```

Then open **`http://localhost:8777/webclient/app/index.html`**.

> Serve from the **repo root**, not `webclient/app/`. The client fetches its JSON manifests
> from `/webclient/app/…` and its images from `/assets/images/…`; rooting at the repo makes
> both resolve from a single origin. (Any static server works — `npx http-server -p 8777 .`,
> etc.)

## How the client finds the server

`defaultServerUrl()` in `webclient/app/app.js`:

1. `window.AA_WS` if set (console/pre-load override), else
2. on a **dev origin** (localhost / private-LAN IP / `*.local`): a `?ws=<url>` query param
   (persisted; `?ws=reset` clears it) → a saved `localStorage.aa_ws` → else **the same host
   that served the page, on port 5695**, else
3. the hosted production `wss://…`.

So on `localhost` it just connects to `ws://localhost:5695`. The override is honored **only**
on dev origins, so a stray `?ws=` link can never redirect a production login elsewhere.

Handy forms:
- `…/index.html?ws=ws://localhost:5696` — target the legacy RPC port instead.
- Testing on a **phone on your LAN**: browse to `http://<your-PC-IP>:8777/webclient/app/index.html`
  — it auto-targets `ws://<your-PC-IP>:5695` (make sure the server binds/allows it and the
  firewall permits 5695/8777).

## Playing a match

Quick Match pairs two queued players. Open the URL in **two tabs**, **Register** two accounts
(the local server persists them under `ausers/`), pick a 3-character team in each, and Quick
Match both — they'll pair into a live match against the local server. Impmon appears in
char-select (unlocked accounts / `all_unlock`; new accounts may need the unlock).

Stop everything by closing the two spawned windows.
