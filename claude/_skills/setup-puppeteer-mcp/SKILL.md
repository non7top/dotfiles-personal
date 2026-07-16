---
name: setup-puppeteer-mcp
description: Use when the user wants Puppeteer browser automation (navigate, click, fill, screenshot a page) available in the current project, or asks to "set up puppeteer" / "add browser automation here". Adds a project-scoped Puppeteer MCP server instead of enabling it globally, so a docker container only starts for projects that actually asked for it.
---

# Setup Puppeteer MCP (per project)

Registers the `mcp/puppeteer` Docker-based MCP server for the **current
project only**, via a `.mcp.json` in the project root — not in global
`~/.claude/settings.json`. That keeps a `docker run --rm` container from
spinning up on every Claude Code session everywhere.

## Steps

1. Confirm Docker is available: `docker info` (if it fails, tell the user
   Docker must be running first and stop).
2. From the project root, run:

   ```bash
   claude mcp add --transport stdio puppeteer --scope project \
     -- docker run -i --rm --shm-size=2g mcp/puppeteer
   ```

   This creates or updates `./.mcp.json` with:

   ```json
   {
     "mcpServers": {
       "puppeteer": {
         "command": "docker",
         "args": ["run", "-i", "--rm", "--shm-size=2g", "mcp/puppeteer"]
       }
     }
   }
   ```

3. Tell the user: project-scoped servers require a one-time approval —
   Claude Code will prompt to trust `.mcp.json` the next time the session
   (re)starts in this project, or they can check status with
   `claude mcp list`.
4. If the user doesn't want this checked into the project's own repo
   (e.g. it's personal-only, or the project doesn't want a docker
   dependency committed for teammates), use `--scope local` instead of
   `--scope project` — that stores it in `~/.claude.json` under this
   project's path instead of writing `.mcp.json`.

## When not to use this

If the user wants Puppeteer available in *every* project by default, this
skill is the wrong tool — that's a global `mcpServers` entry in
`~/.claude/settings.json` instead, which is deliberately what this skill
avoids defaulting to.
