Antigravity CLI config
======================

Files in this directory sync into ``~/.gemini`` (``_statusline-command.sh`` becomes
``~/.gemini/statusline-command.sh``, ``_title-command.sh`` becomes
``~/.gemini/title-command.sh``).

Configuration and settings
--------------------------

Antigravity CLI (``agy``) stores its global configuration in
``~/.gemini/antigravity-cli/settings.json``.

This repository does not sync ``settings.json`` directly as a dotfile because it
contains machine-local state, session history, and workspace paths (such as
``trustedWorkspaces`` and ``permissions.allow``), and ``agy`` rewrites it at runtime.

Instead, generic baseline settings are maintained in ``gemini/settings.template.json``
and merged into live configuration using ``frankensettings`` (``fsettings``):

.. code-block:: bash

   # Preview changes
   fsettings gemini/settings.template.json ~/.gemini/antigravity-cli/settings.json

   # Apply template to live settings
   fsettings push gemini/settings.template.json ~/.gemini/antigravity-cli/settings.json

   # Pull new generic settings from live configuration back into template
   fsettings pull gemini/settings.template.json ~/.gemini/antigravity-cli/settings.json

``fsettings`` expands ``~`` and ``$HOME`` during push (since ``agy`` does not expand
them in JSON configuration), scrubs private fields like ``trustedWorkspaces`` during
pull, and preserves unmanaged runtime permissions.

Sandbox mode
------------

Terminal sandboxing is disabled by setting ``"enableTerminalSandbox": false`` in
``~/.gemini/antigravity-cli/settings.json``.

The default sandboxed execution restricts filesystem scans, lacks direct network
access, and blocks package manager repositories with proxy errors. Confining
commands inside the sandbox forces the model to attempt weird, invalid bypasses
rather than running standard development commands directly.
