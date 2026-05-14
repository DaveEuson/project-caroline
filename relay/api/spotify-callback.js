export default function handler(req, res) {
  const code = (req.query.code || '').replace(/[^A-Za-z0-9._~+/-]/g, '');
  const error = (req.query.error || '').replace(/[<>"'&]/g, '');

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.status(200).send(`<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Caroline — Spotify</title>
  <style>
    body { background:#05050a; color:#e2e8f0; font-family:monospace; display:flex; align-items:center; justify-content:center; height:100vh; margin:0; text-align:center; }
    .ok { color:#1db954; font-size:1.1rem; }
    .err { color:#f87171; font-size:1.1rem; }
    .sub { color:#64748b; font-size:.85rem; margin-top:.5rem; }
  </style>
</head>
<body>
  <div>
    ${error
      ? `<div class="err">Spotify error: ${error}</div><div class="sub">You can close this window.</div>`
      : `<div class="ok">Connected to Caroline</div><div class="sub">This window will close automatically.</div>`
    }
  </div>
  <script>
    (function() {
      try {
        if (window.opener) {
          window.opener.postMessage(
            ${error
              ? `{ type: 'caroline_spotify_error', message: 'Spotify error: ${error}' }`
              : `{ type: 'caroline_spotify_code', code: ${JSON.stringify(code)} }`
            },
            '*'
          );
        }
      } catch(e) {}
      setTimeout(function() { try { window.close(); } catch(e) {} }, 1200);
    })();
  </script>
</body>
</html>`);
}
