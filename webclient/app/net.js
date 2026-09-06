// net.js — WebSocket + JSON transport for the Anime Arena web client.
// Speaks the protocol in ../../MATCH_PROTOCOL.md: every frame is {type, ...fields}.
// Classic script (no modules) so it loads over file:// and any static host.

class AANet {
  constructor() {
    this.ws = null;
    this.url = null;
    this.handlers = {};     // type -> [fn]
    this.statusFn = () => {};
    this._pingTimer = null; // keepalive so an idle lobby socket isn't dropped + reconnected
  }

  // A lightweight ping every 25s (well under the ~60s idle timeout of nginx / most load balancers)
  // so a player sitting idle in the lobby keeps traffic flowing. Without it the socket goes silent,
  // a proxy closes it, and the client reconnects — a churn loop that also floods the server log.
  // The server replies "pong"; nothing needs to consume it.
  _startKeepalive() {
    this._stopKeepalive();
    this._pingTimer = setInterval(() => {
      if (this.ws && this.ws.readyState === WebSocket.OPEN) this.send("ping", {});
      else this._stopKeepalive();
    }, 25000);
  }
  _stopKeepalive() { if (this._pingTimer) { clearInterval(this._pingTimer); this._pingTimer = null; } }

  onStatus(fn) { this.statusFn = fn; }

  // Register a handler for a server message type (or "*" for all).
  on(type, fn) { (this.handlers[type] = this.handlers[type] || []).push(fn); }

  connect(url) {
    this.url = url;
    return new Promise((resolve, reject) => {
      let ws;
      try { ws = new WebSocket(url); }
      catch (e) { reject(e); return; }
      this.ws = ws;
      ws.onopen = () => { this.statusFn("connected"); this._startKeepalive(); resolve(); };
      ws.onerror = () => { this.statusFn("error"); reject(new Error("socket error")); };
      ws.onclose = (e) => { this._stopKeepalive(); this.statusFn("disconnected"); this._emit("_close", { code: e.code }); };
      ws.onmessage = (ev) => {
        let m; try { m = JSON.parse(ev.data); } catch { return; }
        this._emit(m.type, m);
        this._emit("*", m);
      };
    });
  }

  // Send {type, ...payload} as one JSON frame.
  send(type, payload) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(Object.assign({ type }, payload || {})));
      return true;
    }
    return false;
  }

  close() { if (this.ws) this.ws.close(); }

  _emit(type, m) {
    (this.handlers[type] || []).forEach((h) => { try { h(m); } catch (e) { console.error(e); } });
  }
}
