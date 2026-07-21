---
title: Routines
parent: Concepts
nav_order: 4
---

# Routines

**YANA Routines** are named sets of steps executed as a single unit.

Routines are declared in the blueprint. You can call one routine from another.
Use routines to organize your blueprint into smaller, focused and reusable units.

Every routine has a name and a list of steps. The name is used to reference the routine in other routines or in the command line. The steps are executed in the order they are defined in the routine.

Routine names must be unique within a blueprint and contain only alphanumeric characters and underscores.

The special dot-routine (`.`) is the default routine.

## Steps

Routine steps can be of two kinds: **Action Steps** and **Routine Steps**.

**Action Steps** are functions that perform specific tasks within a blueprint.
They modify system state (install packages, write files, start services, etc.). To define an action step, use the `action` key in the step definition. The value of the `action` key is the name of the action function to execute.

Action names must contain only alphanumeric characters and underscores. Every action defined in a routine must have a corresponding action function defined in the module scripts or in one of its dependencies.

**Routine Steps** are calls to other routines. They allow you to compose routines from smaller routines. To define a routine step, use the `routine` key in the step definition. The value of the `routine` key is the name of the routine to execute. It accepts the following formats:

- `routine_name` - calls a routine defined in the same blueprint
- `module_name:routine_name` - calls a routine defined in a dependency module

> You can define `routine` or `action` step, but not both in the same step.

For every step you can additionally define:

- `args` - [Step Arguments](#step-arguments)
- `if` - [Step Conditions](#step-conditions)
- `on_error` - [Error Handling](#error-handling)

### Step Arguments

Step arguments are the inputs to the action or routine. They allow you to parameterize your steps and make them more flexible.
Step Arguments defined as key-value pairs, where the key is the name of the argument and the value is its value. Keys must be unique within a step and contain only alphanumeric characters and underscores. Values can be of any type: string, number, boolean, array or object.

Step Arguments can include sensitive values, similarly to blueprint parameters. To define the sensitive argument, use the `*` suffix in the argument name, e.g. `my_secret*`. To read more about sensitive values, see [Sensitive Parameters](blueprints.md#sensitive-parameters).

Step arguments are passed to the action function as named arguments (for PowerShell) or as variables in the function scope (for Bash). Complex values (arrays and objects) are passed as PowerShell objects (for PowerShell) or as JSON strings (for Bash).

### Step Conditions

Step conditions allow you to control whether a step should be executed based on certain conditions. They are defined using the `if` key in the step definition. The value of the `if` key is a boolean expression that converts to true or false. Empty value, `false` or `0` are considered false, everything else is considered true.

### Error Handling

Error handling allows you to define how to handle errors that occur during the execution of a step. You can define an `on_error` key in the step definition, which can have the following values:

- `stop` - stops the routine execution (default)
- `continue` - continue executing the steps in the routine
- `retry` - retry the step execution (you can also define `max_retries` and `retry_delay` keys to control the retry behavior)

For a routine step, the `on_error` key sets the error handling behavior for the entire routine being called.

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

## Executing Routines

When running `yana`, you specify which routine to execute:

```bash
yana apply -source <path/url to module> -routine setup
```
