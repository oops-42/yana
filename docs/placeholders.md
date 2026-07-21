---
title: Placeholders
parent: Concepts
nav_order: 6
---

# Value Placeholders

You can use placeholders in your blueprints to represent values that will be provided at runtime. Placeholders are defined using the syntax `${<context>:<name>}` where `context` is the source of the value and `name` is the specific value to retrieve. If the placeholder cannot be resolved, it will be replaced with an empty value.

Placeholder can be included in any string value (e.g., `greeting: "Hello, ${param:name}!"`) or as a standalone value (e.g., `count: ${param:count}`). When used in a string, the placeholder output is converted to string or JSON string if it returns an array or object. When used as a standalone value, the placeholder output will be converted to the appropriate type (string, number, boolean, array or object) based on the context.

YANA supports several contexts for placeholders, including:

* `param`: Parameters defined in the blueprint
* `env`: Environment variables
* `output`: Outputs from previous actions
* `var`: Dynamic variables defined as [var-functions](functions.md#vars)
* `item`: Current item in a loop (used in `foreach` loops)

## Params

To access a parameter in your blueprint, use the `${param:<name>}` syntax, where `name` is the name of the parameter defined in the blueprint. You can access the inner properties of a parameter using dot-notation, e.g. `${param:<name>.<property>}`. To access an array element, use the syntax `${param:<name>[<index>]}`. If the parameter name is not found, the placeholder will be replaced with an empty value.

Below is an example of a blueprint that uses placeholders to access parameters:

```yaml
params:
  - param1: my_param
  - param2:
      - item1
      - item2
      - key1: value1
        key2: value2
  - param3:
      key1: value1
      key2: value2

routines:
  .:
    actions:
      - name: my_action
        args:
          param1: ${param:param1}
          param2: ${param:param2[0]}
          param3: ${param:param2[2].key1}
          param4: ${param:param3.key2}
```

## Environment Variables

To access an environment variable, use the `${env:<name>}` syntax, where `name` is the name of the environment variable. Since environment variables are strings, you can not access inner properties or array elements. If the environment variable name is not found, the placeholder will be replaced with an empty value.

For example, `${env:PATH}` would retrieve the value of the `PATH` environment variable.

## Outputs

After the execution of an action, you can access its outputs using the `${output:<name>}` syntax, where `name` is the name of the action that produced the output. If the action name is not found, the placeholder will be replaced with an empty value.

Every action output has values: `out`, `err`, `success` and `failed`. You can access them using the syntax `${output:<action_name>.out}`, `${output:<action_name>.err}`, `${output:<action_name>.success}` and `${output:<action_name>.failed}` respectively. `out` is the standard output of the action function, `err` is the standard error (or PowerShell exception message). `err` is populated only if the action function returns a non-zero exit code or throws an exception, otherwise it is empty. `success` is true if the action succeeded, `failed` is true if the action failed.

If the action returns a Powershell object or JSON string, you can access the inner properties of the output using dot-notation similarly to how you access parameters.

Below is an example of a blueprint that uses placeholders to access outputs:

```yaml
routines:
  .:
    actions:
      - name: action1
      - name: action2
        args:
          input: ${output:action1.out.key1}
          error: ${output:action1.err}
        if: ${output:action1.success}
```

## Dynamic Variables

Dynamic variables are defined as [var-functions](functions.md#vars). When you access a dynamic variable using the `${var:<name>}` syntax, the corresponding var-function is executed and its return value is used as the value of the placeholder. If the var-function name is not found, the placeholder will be replaced with an empty value. Var-function can return a string, an array or an object (as JSON string or as Powershell object/hashtable). You can access the inner properties of an object using dot-notation the same way as you access parameters: `${var:<name>.<key>[<index>].<subkey>}`.

## Loop Items

When using a `foreach` loop in your blueprint, you can access the current item in the loop using the `${item:<property>}` placeholder. Item has two properties: `key` and `value`. You can access them using `${item:key}` and `${item:value}`. The `foreach` loop supports iteration over arrays and objects. When iterating over an array, the `key` property will be the index of the current item, and the `value` property will be the value of the current item. When iterating over an object, the `key` property will be the key of the current item, and the `value` property will be the value of the current item. Keys are always strings, while values can be strings, arrays or objects. You can access the inner properties of an object using dot-notation the same way as you access parameters: `${item:value.<key>[<index>].<subkey>}`.

## Embedded Placeholders

Placeholders can be embedded in strings, allowing you to construct dynamic values based on the current context. When a placeholder is embedded in a string, it will be replaced with its corresponding value at runtime. You can use multiple placeholders in a single string, and they will all be replaced with their respective values.

Placeholders may also include other placeholders in their names, allowing for dynamic placeholder resolution. For example, `${param:name_${var:os_name}}` would resolve the `os_name` variable first, and then use its value to construct the parameter name. So, for example, if the `os_name` variable returns `linux`, the placeholder would resolve to `${param:name_linux}`.
