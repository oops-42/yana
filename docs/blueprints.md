---
title: Blueprints
parent: Concepts
nav_order: 2
---

# Blueprints

**YANA Blueprint** is a YAML file (`.yana.yaml`) that describes your automation: metadata, parameters, modules and dependencies, routines and lifecycle events.

You are free to choose the structure of your blueprints - use a single file describing everything or split into multiple focused files.

## Blueprint Fields

A blueprint can define:

| Field | Description |
|---|---|
| `name` | Module name |
| `version` | Module version |
| `description` | Short description |
| `author` | Author name or contact |
| `license` | License identifier (e.g. `MIT`) |
| `modules` | List of modules this blueprint depends on |
| `params` | List of parameters this blueprint accepts |
| `extends` | List of blueprints this blueprint extends (inherits from) |
| `routines` | Named sets of actions to execute |
| `events` | Lifecycle event handlers |

> Full schema reference is coming. Fields above reflect current understanding and are subject to change.

## Dependencies

Dependencies are declared in the blueprint in `modules` section and resolved by YANA Toolkit before packaging. Sources can be:

- A local path
- A Git repository URL

YANA Toolkit fetches all dependencies and bundles them into the yanapack, so the target node does not need network access at apply time.

## Example Blueprint

```yaml
name: my-module
version: 1.0.0
description: Example YANA module
author: Your Name
license: MIT

params:
  nginx_port: 8080

modules:
  stdlib:
    source: git@github.com:oops-42/yana-modules.git
    path: std
  nginx:
    source: ${env:HOME}/my-modules
    path: extras/nginx

extends:
  - nginx

routines:
  .:
    - action: install_packages
      args:
        packages:
          - curl
          - git
```
