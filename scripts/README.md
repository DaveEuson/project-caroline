# Project Caroline Scripts

These scripts are repo-supported QA and release helpers. They are safe to keep in
the public repository when they follow these rules:

- Use synthetic test people, memories, and relationships only.
- Do not hard-code private host passwords, API keys, OAuth tokens, Discord
  tokens, or personal memory facts.
- Pass host addresses and SSH users through command-line options.
- Write raw benchmark and smoke-test output under `reports/`; that folder is
  ignored by git.

## Common Checks

```powershell
node tests\command-language.test.js
node scripts\smoke-devices.js --target Pi=192.168.1.50
node scripts\benchmark-ollama-direct-ssh.js --ssh user@host --models small
```

The benchmark prompts intentionally use fictional fixture data so model quality,
memory behavior, and safety behavior can be tested without leaking real user
details.
