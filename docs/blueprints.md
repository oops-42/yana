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
| `description` | Short description of the module |
| `author` | Author name or contact |
| `license` | License identifier (e.g. `MIT`) |
| `supports` | List of supported platforms (`windows`, `linux`, `macos`) |
| `dependencies` | List of modules this blueprint depends on |
| `params` | List of parameters this blueprint accepts |
| `routines` | Named sets of actions to execute |
| `events` | Lifecycle event handlers |

> Full schema reference is coming. Fields above reflect current understanding and are subject to change.

## Dependencies

Dependencies are declared in the blueprint in `dependencies` section and resolved by YANA Toolkit before packaging. Sources can be:

- A local path
- A Git repository URL

YANA Toolkit fetches all dependencies and bundles them into the yanapack, so the target node does not need network access at apply time.

## Parameters

The blueprint can define parameters that can be passed to the blueprint at runtime. Parameters are defined in the `params` section of the blueprint. Each parameter is defined as a key-value pair, where the key is the name of the parameter and the value is its default value. If a parameter is not provided at runtime, its default value will be used. Parameter names must be unique within a blueprint and contain only alphanumeric characters and underscores. Parameter values can be of any type: string, number, boolean, array or object.

### Sensitive Parameters

Sensitive parameters are defined similarly to regular parameters. Sensitive values are encrypted using a per-session ephemeral asymmetric key pair, so if they are leaked to logs, they can not be decrypted without private key. The encrypted sensitive values are represented as `<YANAencrypted:base64-encoded-ciphertext>`.

To define a sensitive parameter, use the `*` suffix in the parameter name, e.g. `my_secret*`.

Sensitive parameters can be embedded into other string values, e.g. `connection_string: "Server=myserver;User=myuser;Password=${param:my_db_password};Database=mydb"`, where `my_db_password` is a sensitive parameter declared earlier as `my_db_password*: ${var:my_password_from_vault}`. YANA handles the decryption of sensitive parameters automatically.

For PowerShell, you can also declare the parameter as a `SecureString` type. In this case, the parameter will be automatically converted to a `SecureString` object.

For Bash, the parameter will be passed to action function as a string argument and you shall use function `YANA:decrypt` to decrypt it. Same applies to PowerShell, if you declare the parameter as a `String` type.

## Inheritance

The blueprint can inherit from other blueprints using the `inherits` section. While defining inheritance, you specify which modules will be applied before the current blueprint. The modules are applied in the order they are listed in the `inherits` section.

## Example Blueprint

```yaml
name: my-module
version: 1.0.0
description: Example YANA module
author: Your Name
license: MIT

params:
  nginx_port: 8080

dependencies:
  - name: stdlib
    source: git@github.com:oops-42/yana-modules.git
    path: std
  - name: nginx
    source: ${env:HOME}/my-modules
    path: extras/nginx

routines:
  .:
    - action: install_packages
      args:
        packages:
          - curl
          - git
    - routine: nginx:install
      args:
        port: ${param:nginx_port}
```
