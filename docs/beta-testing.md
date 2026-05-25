# Beta Tester Guide

Thank you for testing Project: Caroline. This guide is for testers who want to try the current beta on real hardware and send useful feedback.

Project: Caroline is a local-first AI kiosk/dashboard for Raspberry Pi, Ubuntu, Pop!_OS, experimental Steam Deck setups, and browsers on your home network. It includes chat, memory, calendar help, local tasks, weather, music, smart-home hooks, system status, phone browser access, and an optional desktop Companion app.

This beta is not expected to be perfect. The most useful feedback is where setup is confusing, where something breaks, where AI replies feel wrong, or where the app already feels surprisingly useful.

## What You Need

- A Raspberry Pi, Ubuntu/Pop!_OS computer, Ubuntu VM, or Steam Deck in Desktop Mode.
- Internet access during install.
- A stable local network connection.
- About 15 minutes for a first pass.
- Optional: a phone or tablet on the same Wi-Fi if you want to test the mobile browser layout.
- Optional: Google Calendar, Spotify, Philips Hue, [Discord](discord.md), weather, tides, radio, or local AI if you want to test one integration.

Please do not paste API keys, OAuth tokens, Discord bot tokens, passwords, or private calendar details in feedback.

## Pick Your Install Path

Choose the guide that matches your device:

- Raspberry Pi OS: [How to install on Raspberry Pi OS](how-to-raspberry-pi-os.md)
- Ubuntu Server: [How to install on Ubuntu Server](how-to-ubuntu-server.md)
- Ubuntu Desktop / Pop!_OS: [How to install on Ubuntu Desktop](how-to-ubuntu-desktop.md)
- Steam Deck: [Experimental Steam Deck / SteamOS install](how-to-steamos.md)

If you already have Caroline installed, update from the `release` channel before testing.

## 15-Minute Test Checklist

1. Install or update Caroline using the guide for your device.
2. Open the dashboard at `http://YOUR-CAROLINE-IP:8080/` from the kiosk screen, a desktop browser, or a phone browser on the same network.
3. Send one normal chat message, such as `What should I test first?`
4. Open **Settings** and check whether the device type, AI provider, and model look reasonable.
5. Try one widget or integration:
   - Calendar: connect Google Calendar or confirm Caroline asks you to connect.
   - Tasks: add and complete a task.
   - Hue, Spotify, Discord, weather, tides, or radio: enable only if you already have it configured.
6. Refresh the page and confirm the dashboard still loads.
7. If you have a phone handy, open the same URL there and check that chat, avatar, **Settings**, and the SYNC/status pills fit without sideways scrolling.
8. If an update button is visible, check whether the update status is readable.
9. Write down the first thing that was confusing, broken, slow, or surprisingly good.
10. Submit a [Beta test report](https://github.com/Project-Caroline/project-caroline/issues/new?template=beta_test_report.md).

## What To Include In Your Report

Helpful feedback:

- Device type, OS version, and browser.
- Which install guide you used.
- Fresh install or update.
- Whether kiosk mode was enabled.
- AI provider and model if you noticed them.
- Whether chat worked.
- Which widget or integration you tested.
- The exact error message or screenshot if something broke.
- One thing that felt polished.
- One thing that felt confusing.

If something fails, a short report is still useful. "I got stuck at step 3 because the URL did not load" is exactly the kind of feedback this beta needs.

## Feedback Link

Submit results here:

[Open a Project: Caroline beta test report](https://github.com/Project-Caroline/project-caroline/issues/new?template=beta_test_report.md)

Before submitting, double-check that your report does not include secrets:

- API keys
- OAuth tokens
- Discord bot tokens
- Passwords
- Full credential files
- Private calendar details
