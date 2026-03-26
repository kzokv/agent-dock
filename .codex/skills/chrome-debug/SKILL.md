---
name: chrome-debug
description: How to use Chrome DevTools MCP for browser debugging. Use when you need to inspect pages, take screenshots, debug UI issues, or verify visual changes.
---

# Chrome DevTools Debugging

This skill explains how to use the Chrome DevTools MCP for browser debugging and UI verification.

## Setup

Before using Chrome DevTools MCP, you must launch Chrome in headless mode with remote debugging enabled:

```bash
npm run chrome &
```

This runs Chrome with the required flags for Docker/containerized environments:

- `--remote-debugging-port=9222` - Enables MCP connection
- `--no-sandbox` - Required for Docker
- `--headless` - Runs without display
- `--disable-gpu` - Avoids GPU issues in containers

Wait a few seconds for Chrome to start before using MCP tools.
