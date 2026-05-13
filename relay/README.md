# Caroline OAuth Relay

Serverless Vercel function that handles Google OAuth token exchange on behalf of Caroline installations. Users never need to create their own Google Cloud project.

## Deploy to Vercel

1. Go to vercel.com and sign in with GitHub
2. Click **Add New Project**
3. Import the `project-caroline` repository
4. Set **Root Directory** to `relay`
5. Add these environment variables:
   - `GOOGLE_CLIENT_ID` — from your Google Cloud OAuth credentials
   - `GOOGLE_CLIENT_SECRET` — from your Google Cloud OAuth credentials
6. Click **Deploy**

Your relay URL will be: `https://your-project.vercel.app/api/google`

## How it works

- `POST /api/google` with `{ action: "exchange", code, redirect_uri, code_verifier }` — exchanges an auth code for tokens
- `POST /api/google` with `{ action: "refresh", refresh_token }` — refreshes an access token

Stateless — no user data is stored or logged.

## Fallback

If the relay is unavailable or Google blocks the request (e.g. app not yet verified), Caroline automatically falls back to the manual credential import flow.
