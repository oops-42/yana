---
title: Functions
parent: Concepts
nav_order: 3
---

# Functions: Helpers, Actions, Verifiers

YANA functions are pure PowerShell/Bash functions organized into script files. There are three types of functions: **Helpers**, **Actions** and **Verifiers**.

## Helpers

**YANA Helpers** are small utility functions used to add dynamism to blueprints.
They compute values, transform data, or perform lookups - they do not modify system state.

## Actions

**YANA Actions** are functions that perform specific tasks within a blueprint.
They modify system state (install packages, write files, start services, etc.).

## Verifiers

**YANA Verifiers** check the state of the system before or after applying actions.
They are used to achieve idempotency - an action is only applied if the verifier determines it is needed.

Verifiers are optional companions to Actions. A verifier paired with an action allows YANA Engine to skip the action if the desired state is already present.

## Naming Convention

YANA does not impose complex DSL. Functions are plain PowerShell/Bash, yet shall follow the naming convention to be discoverable by YANA Engine and Toolkit.

All YANA functions must follow the pattern `<prefix><function_name>[@<scenario>]`, where:

* Action and Verifier functions must begin with `YANAaction:` prefix, but verifiers must also end with `@verify` suffix.
* Helper functions must begin with `YANAhelper:` prefix.
* Test functions must begin with `YANAtest:` prefix.

## Location

Scripts containing helpers, actions and verifiers are stored in the `.yana/` directory of the module and are automatically loaded by YANA Engine when the module is applied. Scripts can also contain tests for the functions, which are automatically discovered and run by the YANA Testing Framework.

```
my-module/
  .yana/
    packages.sh   # or packages.ps1
    files.sh      # or files.ps1
    metrics.sh    # or metrics.ps1
```

There is no enforced file naming inside `.yana/`. All `.sh` (or `.ps1`) files are loaded in natural sort order.

## Module Repository

YANA does not ship built-in helpers, actions or verifiers. You declare the modules you need in your blueprint.

The [YANA Modules Repository](https://github.com/oops-42/yana-modules) contains a collection of reusable modules.
You can also create your own modules and share them.

## Testing Functions

Write unit tests for your functions using the [YANA Testing Framework](testing.md).
