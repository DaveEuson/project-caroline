export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method === 'GET') {
    const CLIENT_ID_GET = process.env.GOOGLE_CLIENT_ID;
    return res.status(200).json({ client_id: CLIENT_ID_GET || null });
  }
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
  const CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;
  if (!CLIENT_ID || !CLIENT_SECRET) return res.status(500).json({ error: 'Relay not configured' });

  const { action, code, redirect_uri, code_verifier, refresh_token } = req.body || {};

  try {
    if (action === 'exchange') {
      if (!code || !redirect_uri) return res.status(400).json({ error: 'Missing code or redirect_uri' });
      const params = new URLSearchParams({
        code,
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        redirect_uri,
        grant_type: 'authorization_code',
      });
      if (code_verifier) params.set('code_verifier', code_verifier);
      const resp = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params.toString()
      });
      const data = await resp.json();
      if (!resp.ok) return res.status(resp.status).json({ error: data.error, error_description: data.error_description });
      return res.status(200).json({
        access_token: data.access_token,
        refresh_token: data.refresh_token,
        expires_in: data.expires_in,
        token_type: data.token_type
      });
    }

    if (action === 'refresh') {
      if (!refresh_token) return res.status(400).json({ error: 'Missing refresh_token' });
      const resp = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          refresh_token,
          client_id: CLIENT_ID,
          client_secret: CLIENT_SECRET,
          grant_type: 'refresh_token'
        }).toString()
      });
      const data = await resp.json();
      if (!resp.ok) return res.status(resp.status).json({ error: data.error });
      return res.status(200).json({ access_token: data.access_token, expires_in: data.expires_in });
    }

    return res.status(400).json({ error: 'Unknown action' });
  } catch (e) {
    return res.status(500).json({ error: 'Relay error' });
  }
}
