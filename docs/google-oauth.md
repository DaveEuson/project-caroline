# Google OAuth Setup

Caroline uses a Google **Desktop app OAuth client** for personal Calendar and Google Tasks access. Do not use a service-account JSON for normal setup. A service account is a separate robot account, and its numeric client ID will trigger Google errors such as `redirect_uri_mismatch`.

## Create the OAuth Client

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Select an existing project, or create a new project named something like `Project Caroline`.
3. Enable these APIs in **APIs & Services > Library**:
   - Google Calendar API
   - Google Tasks API
   - Google Sheets API, only if you still use the legacy Sheets task sync
4. Open **Google Auth Platform**.
5. If prompted, configure the app/consent screen:
   - App name: `Caroline`
   - User support email: your Gmail address
   - Audience/User type: External is fine for a personal Gmail account
   - Contact email: your Gmail address
6. If the app is in testing mode, add your Gmail address under **Test users**.
7. Go to **Google Auth Platform > Clients**.
8. Click **Create client**.
9. Set **Application type** to **Desktop app**.
10. Name it `Caroline Desktop`.
11. Click **Create**.
12. Download the JSON immediately.

The downloaded OAuth client JSON should contain an `installed` object, and its `client_id` should end with:

```text
.apps.googleusercontent.com
```

If the JSON says `"type": "service_account"`, or the client ID is only a long number, it is the wrong file for normal Caroline sign-in.

## Connect It In Caroline

1. Open Caroline.
2. Go to **Settings > Google**.
3. Use **Import OAuth JSON** and select the Desktop app JSON you downloaded.
4. Click **Connect Google**.
5. Sign in with the same Google account you added as a test user.
6. If Google redirects to a localhost/error page in a remote browser, copy the full URL from the address bar and paste it into **Finish Google Sign-In** in Caroline.

## Kiosk vs Browser

The Pi kiosk and a normal browser use the same setup screen. The only difference is where Google lands after consent:

- **Pi kiosk:** the loopback callback can complete directly on the Pi.
- **Remote browser/laptop:** the browser may land on `127.0.0.1` on your laptop. Copy that final URL and paste it into **Finish Google Sign-In**.

## Troubleshooting

- `redirect_uri_mismatch`: you probably used a Web Application client, service-account JSON, or an old invalid client. Create a new **Desktop app** OAuth client and import that JSON.
- `Access blocked` / unverified app warning: make sure your Gmail account is listed as a test user, then continue through the advanced/testing prompt.
- Caroline says `Import Desktop OAuth JSON`: the saved Google client ID is not a valid OAuth client ID ending in `.apps.googleusercontent.com`.

Google references:

- [Manage OAuth clients](https://support.google.com/cloud/answer/6158849)
- [Create access credentials for Google Workspace APIs](https://developers.google.com/workspace/guides/create-credentials)
- [Configure the OAuth consent screen](https://developers.google.com/workspace/guides/configure-oauth-consent)
