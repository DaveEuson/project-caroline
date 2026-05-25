# How To Set Up Discord

Project: Caroline can relay chat through Discord so you can talk to the kiosk from a server channel or a private direct-message thread.

This is optional. If you only want local kiosk, phone, browser, or Companion app chat, you can skip Discord.

## What You Need

- A Discord account.
- Permission to add a bot to a Discord server.
- A Project: Caroline host already running.
- About 10 minutes.

Keep the bot token private. Do not paste it into GitHub issues, beta reports, screenshots, Discord posts, or support messages.

## Choose A Destination

| Mode | Best for | What Caroline needs |
| --- | --- | --- |
| Server channel | A shared room where Caroline posts and reads messages | Bot token and Channel ID |
| Direct message | Private chat between you and Caroline | Bot token and your Discord User ID, then Caroline creates the DM channel |

Direct-message mode is friendlier once it is configured, but it still needs a bot. Discord does not currently let Caroline join Discord without some kind of bot/app credential.

## Step 1: Create The Discord App And Bot

1. Open the [Discord Developer Portal](https://discord.com/developers/applications).
2. Select **New Application**.
3. Name it something clear, such as `Project Caroline Home`.
4. Open the new application.
5. Go to **Bot**.
6. Create the bot if Discord asks you to.
7. Copy or reset the **Bot Token**.
8. Turn on **Message Content Intent** so Caroline can read message text.

The token is the long secret value Caroline needs. It is not the Application ID, Client ID, Public Key, Channel ID, or User ID.

## Step 2: Invite The Bot To Your Server

1. In the Developer Portal, open your application.
2. Go to **OAuth2**.
3. Use the install or URL generator flow.
4. Select the `bot` scope.
5. Give the bot these permissions:
   - View Channels
   - Send Messages
   - Read Message History
6. Open the generated install URL.
7. Add the bot to the Discord server you want Caroline to use.

You can use a private server with only you and Caroline in it. That is usually the cleanest beta setup.

## Step 3: Turn On Developer Mode In Discord

Caroline needs numeric Discord IDs, so Developer Mode must be enabled.

1. Open Discord.
2. Open **User Settings**.
3. Find **Advanced**.
4. Enable **Developer Mode**.

After this, right-clicking users, channels, and servers should show **Copy ID**.

## Step 4A: Use A Server Channel

Use this if you want Caroline in a channel.

1. In Discord, right-click the channel Caroline should use.
2. Choose **Copy ID**.
3. Open Caroline.
4. Go to **Settings -> Connect -> Discord**.
5. Check **Enable Discord**.
6. Set **Destination** to **Server channel**.
7. Paste the **Bot Token**.
8. Paste the **Channel ID**.
9. Click **Test Discord**.
10. Click **Save & Apply**.

If the test passes, Caroline should send a test message to that channel and should be able to read new human messages from it.

## Step 4B: Use A Direct Message

Use this if you want a private chat thread.

1. Make sure the bot is already in a server you share.
2. In Discord, right-click your own user profile or message author name.
3. Choose **Copy ID**.
4. Open Caroline.
5. Go to **Settings -> Connect -> Discord**.
6. Check **Enable Discord**.
7. Set **Destination** to **Direct message**.
8. Paste the **Bot Token**.
9. Paste your **Discord User ID**.
10. Click **Create DM**.
11. Click **Test Discord**.
12. Click **Save & Apply**.

Caroline will create the DM channel and store the DM Channel ID for future sends. You usually do not need to paste the DM Channel ID manually.

## Quick Smoke Test

After saving:

1. Send `hello Caroline` in the configured Discord channel or DM.
2. Watch the kiosk chat history.
3. Confirm Caroline replies in Discord.
4. Ask `what should I test next?`.

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `Unauthorized` or HTTP 401 | Wrong token | Paste the Bot Token from the Bot page, not the app/client ID. |
| `Forbidden` or HTTP 403 | Bot lacks channel permission | Give the bot View Channels, Send Messages, and Read Message History in that channel. |
| `That looks like an ID, not a bot token` | A numeric ID was pasted into Bot Token | Copy the token from Developer Portal -> Bot. |
| `Channel ID should be numeric` | A URL, mention, or token was pasted into Channel ID | Enable Developer Mode, right-click the channel, then Copy ID. |
| Sends work, inbound reads fail | Message Content Intent or Read Message History is missing | Enable Message Content Intent and confirm channel permissions. |
| DM setup fails | Bot does not share a server with you, or DMs are blocked | Add the bot to a shared server and allow DMs from server members. |
| No **Copy ID** menu item | Developer Mode is off | Enable Discord Developer Mode under User Settings -> Advanced. |

## Security Notes

- Treat the bot token like a password.
- Use a dedicated bot for Caroline, not a bot shared with unrelated projects.
- If a token leaks, reset it immediately in the Developer Portal and update Caroline.
- Keep Caroline on your trusted local network.
- Do not post screenshots that reveal the token or full IDs if you do not want those IDs public.

## Official References

- [Discord OAuth2 and permissions](https://docs.discord.com/developers/platform/oauth2-and-permissions)
- [Discord bot documentation](https://discord.com/developers/docs/bots)
- [Discord support: finding user, server, and message IDs](https://support.discord.com/hc/en-us/articles/206346498)
