# Beta Testing Project: Caroline

Project: Caroline is ready for small-group beta testing. The goal for this round is simple: get 10 people to try the app on real hardware and collect enough notes to find the rough edges before the next public release.

## Tester Invite

Use this as a DM, email, Discord post, or LinkedIn message:

```text
Hey! I am looking for 10 people to beta test Project: Caroline, a local AI kiosk/dashboard for Raspberry Pi, Ubuntu/Pop!_OS, Steam Deck, or a browser on your home network.

The test should take about 15 minutes. I am mainly looking for install friction, confusing setup steps, broken widgets, weird AI replies, and anything that feels rough or unclear.

You do not need to be technical, but it helps if you are comfortable opening a terminal and following a checklist. If you want to try it, start here:

https://github.com/Project-Caroline/project-caroline/blob/release/docs/beta-testing.md

Please do not paste API keys, tokens, passwords, or private calendar details in feedback.
```

Shorter version:

```text
I am looking for 10 beta testers for Project: Caroline, a local AI kiosk/dashboard for Pi, Ubuntu/Pop!_OS, Steam Deck, and LAN browsers. It takes about 15 minutes: install/open it, send a chat, try one widget, and report what breaks. Start here: https://github.com/Project-Caroline/project-caroline/blob/release/docs/beta-testing.md
```

## Who To Ask First

Best-fit testers:

- Raspberry Pi users with a spare screen or desk display.
- Ubuntu or Pop!_OS users who are comfortable with terminal installs.
- Steam Deck users willing to test Desktop Mode.
- Friends who will tell you where the instructions are confusing.
- People who use Google Calendar, Spotify, Hue, Discord, or local AI and can test one integration.

Try to recruit 10, but treat 5 completed reports as the first meaningful milestone.

## 15-Minute Test Checklist

1. Pick your install path:
   - Raspberry Pi OS: [How to install on Raspberry Pi OS](how-to-raspberry-pi-os.md)
   - Ubuntu Server: [How to install on Ubuntu Server](how-to-ubuntu-server.md)
   - Ubuntu Desktop / Pop!_OS: [How to install on Ubuntu Desktop](how-to-ubuntu-desktop.md)
   - Steam Deck: [Experimental Steam Deck / SteamOS install](how-to-steamos.md)
2. Install or update Caroline from the `release` channel.
3. Open the dashboard at `http://YOUR-CAROLINE-IP:8080/`.
4. Send one normal chat message, such as `What should I test first?`
5. Open Settings and confirm the device type, AI provider, and model look reasonable.
6. Try one widget or integration:
   - Calendar: connect Google Calendar or confirm it asks you to connect.
   - Tasks: add and complete a task.
   - Hue, Spotify, Discord, weather, tides, or radio: enable only if you actually have it configured.
7. Refresh the page and confirm the dashboard still loads.
8. If there is an update button, check that update status is readable.
9. Write down the first thing that was confusing, broken, slow, or surprisingly good.
10. Submit a [Beta test report](https://github.com/Project-Caroline/project-caroline/issues/new?template=beta_test_report.md).

## What To Report

Helpful feedback:

- Where you got stuck.
- Which install guide you used.
- Device type, OS, browser, and whether kiosk mode was enabled.
- Whether chat worked.
- Which widget or integration you tested.
- The exact error message or screenshot if something broke.
- One thing that felt polished.
- One thing that felt confusing.

Please do not include secrets:

- API keys
- OAuth tokens
- Discord bot tokens
- Passwords
- Full credential files
- Private calendar details

## Success Criteria

For this beta round, success means:

- 10 people agree to test.
- At least 5 people submit a completed report.
- At least 3 different platform paths are covered.
- Every critical install or first-run blocker becomes a GitHub issue.
- The release notes get updated with the most common tester findings.

## Tracking Sheet

Use this lightweight tracker while recruiting:

| Tester | Platform | Invited | Installed | Reported | Notes |
|---|---|---:|---:|---:|---|
| 1 |  |  |  |  |  |
| 2 |  |  |  |  |  |
| 3 |  |  |  |  |  |
| 4 |  |  |  |  |  |
| 5 |  |  |  |  |  |
| 6 |  |  |  |  |  |
| 7 |  |  |  |  |  |
| 8 |  |  |  |  |  |
| 9 |  |  |  |  |  |
| 10 |  |  |  |  |  |
