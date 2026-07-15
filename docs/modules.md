---
title: Modules
parent: Concepts
nav_order: 1
---

# Modules

**YANA Module** is a directory containing a `.yana.yaml` [Blueprint file](blueprints.md) together with any supporting files (scripts, templates, binaries, etc.).

## Example Module Structure

```
my-module/
  .yana.yaml          # blueprint file (required)
  .yanaignore         # list of files to exclude from yanapack (optional)
  .yana/              # directory for helpers, actions and verifiers
    my_functions.sh   # functions for Bash
    my_functions.ps1  # functions for PowerShell
  templates/          # any other files your module needs
  files/
```

## .yanaignore

The `.yanaignore` file works like `.gitignore` and controls what gets excluded from the built yanapack.

By default, the following are always excluded:
- `.git`, `.gitignore`, `.yanaignore`, `.yana.yaml`
- `*.yanatests.sh`, `*.yanatests.ps1`

## Sub-modules

A module may contain sub-modules: sub-directories that have their own `.yana.yaml` file.
