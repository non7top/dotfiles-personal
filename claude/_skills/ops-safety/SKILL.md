---
name: ops-safety
description: Use when changing anything on a remote server, in a service's database or in a web root. Covers SSH host-key mismatches, searching a remote filesystem, writing to a service's data store instead of its own tooling, and keeping PHP files and their backups safe under a web root.
---

# Servers, databases and web roots

## SSH host-key mismatch

Before halting, run cheap read-only checks (`dig` the hostname, recall any DNS change this session). Don't bypass `StrictHostKeyChecking` or delete `known_hosts` entries. Escalate only if unexplained.

## Never scan a whole filesystem on a remote host

No `find /` or `grep -r /` for a path or string you could name: locate the install from a service unit, `ps`, or the app's own config, then `stat`/`ls` that exact path. Backup and storage nodes hold tens of millions of inodes on spinning disks, and one scan starves the jobs running there. Killing the local ssh or task does not stop the remote command: confirm it is gone with `ps` on the host.

## Change systems through their own tools, not direct database writes

Make changes through the service's high-level interface: its CLI, REST/SOAP API, or admin tooling. Never write straight into a service's database when such an interface exists. Raw SQL skips validation, derived state (serials, caches, generated config) and the audit trail.

- A direct DB write needs a written go-ahead from the user for that specific change, given before it runs. Say which interface was unavailable or unsuitable, and show the exact statements.
- Reading from the DB is fine.
- Having read through SQL doesn't license writing through it. Switch tools for the write.
- Check the CLI/API exists before concluding it doesn't.

## PHP files always keep the .php extension

A PHP file's name always ends in `.php`. Never save a copy, backup or temp version of one under another extension (`.bak`, `.old`, `.new`, `.orig`, `~`, `.txt`) inside a web root: the web server serves it as plain text and exposes the source, including credentials. Keep backups outside the web root (a root-only directory), and stage uploads there or under a `.php` name, then `mv` into place. After any edit session on a web root, list it for stray non-`.php` copies and `curl` any suspect name to confirm it is not served.
