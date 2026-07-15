---
title: Routines
parent: Concepts
nav_order: 5
---

# Routines

**YANA Routines** are named sets of actions executed together as a single unit.

Routines are declared in the blueprint. You can call one routine from another.
Use routines to organize your blueprint into smaller, focused and reusable units.

## Dot-routine

The dot-routine (`.`) is the default routine. It is executed if no `-routine` argument is specified.

### Routine Examples

```yaml
routines:
  .:
    - routine: install
    - routine: configure

  install:
    - action: install_packages
      args:
        packages: [nginx]

  configure:
    - action: copy_files
      args:
        src: templates/nginx.conf
        dest: /etc/nginx/nginx.conf
```

## Running Routines

When running `yana`, you specify which routine to execute:

```bash
yana apply -source <path/url to module> -routine setup
```
