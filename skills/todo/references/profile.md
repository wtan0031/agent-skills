# Repo profile — the one-time interview

The profile is what makes "how to test" concrete instead of vague. Interview
once per repo, save, reuse forever; later runs only ask about genuinely new
things. Stored at `~/.claude/todo/profiles/<key>.json`, mode 600.

## Contents
- [What to infer before asking](#what-to-infer-before-asking)
- [The interview](#the-interview)
- [Schema](#schema)
- [Credential rule](#credential-rule)

## What to infer before asking

Never ask for something the repo already states. Check these first and present
findings as defaults to confirm, not as questions:

- `README`, `CONTRIBUTING` — run/build/test commands
- `.env.example`, `.env.sample` — which variables exist (names only)
- `package.json` scripts, `Makefile`, `*.xcodeproj` schemes, `docker-compose.yml`
- `.github/workflows/*` — how CI builds and tests it, which envs it deploys to
- Existing `CLAUDE.md` — commands table, conventions

Ask only for what's genuinely undiscoverable: which account, where credentials
live, which env is safe to touch, and anything the repo contradicts itself on.

## The interview

Batch these into as few AskUserQuestion calls as possible — offer inferred
values as the first option so confirming is one click. Skip any question the
repo already answered.

1. **Environments** — which exist (local / dev / staging / prod), and the URL
   for each. Which are safe to test against, and which must never be touched.
2. **Test accounts** — per environment, the account *identifier* (email or
   username) to sign in with, and its role if roles matter (admin vs member).
3. **Where credentials live** — 1Password/Bitwarden item name, a `.env` key, a
   password manager entry. The pointer only, never the secret.
4. **Second factor** — is there 2FA/SSO on any of these, and what does it need
   (authenticator app, hardware key, SMS)? This is often the real reason an
   item is `access`-blocked, so capture it.
5. **How to run it** — the exact command or app + scheme that gets it in front
   of them, plus anything that must be running first (docker, a tunnel, a VPN).
6. **Seed data** — is there a known-good test record/fixture to exercise flows
   against, and how to reset state between attempts.
7. **Device needs** — does anything require real hardware (a physical phone, a
   card reader, a printer)?

## Schema

```json
{
  "repo_key": "acme-shop",
  "updated": "2026-07-29",
  "run": { "command": "npm run dev", "prereqs": ["docker compose up -d"] },
  "environments": [
    {
      "name": "staging",
      "url": "https://staging.example.com",
      "safe_to_test": true,
      "account": "qa+staging@example.com",
      "role": "admin",
      "credential_location": "1Password → 'Example staging QA'",
      "second_factor": "Okta push"
    },
    {
      "name": "prod",
      "url": "https://example.com",
      "safe_to_test": false,
      "note": "read-only; never write test data here"
    }
  ],
  "seed_data": "Order #10042 is the reusable fixture; reset via `npm run seed`",
  "devices": ["physical iPhone for push notifications"],
  "gaps": ["no test account for the billing admin role"]
}
```

Anything unknown goes in `gaps` rather than being guessed. Every refresh
surfaces `gaps` in the report so they get filled in over time.

## Credential rule

Store **pointers, never secrets**. If the user volunteers an actual password,
API key, or token in their answer:

1. Do not write it to the profile, the list, or any file.
2. Save the *location* instead ("in your password manager under X").
3. Tell them plainly that it wasn't stored and why.

The profile directory is mode 700 and files 600, but that protects account
identifiers and internal URLs — it is not a secret store.
