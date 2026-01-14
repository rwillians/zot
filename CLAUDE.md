# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Run a single test file
mix test test/zot_test.exs

# Run a specific test by line number
mix test test/zot_test.exs:42

# Run tests with coverage
mix test --cover

# Run dialyzer for static analysis
mix dialyzer

# Generate documentation
mix docs

# Format code
mix format
```

## Architecture

Zot is a schema parser and validator library for Elixir, inspired by Zod (TypeScript). It provides type definitions, validation, coercion, and JSON Schema generation.

### Core Components

- **`Zot`** (`lib/zot.ex`): Main API module. Exposes type constructors (e.g., `Z.string()`, `Z.int()`, `Z.map()`), modifiers (e.g., `Z.optional()`, `Z.default()`, `Z.refine()`), and the core `Z.parse/3` function.

- **`Zot.Type`** (`lib/zot/type.ex`): Protocol that all types implement. Defines `parse/3` for validation and `json_schema/1` for JSON Schema conversion.

- **`Zot.Context`** (`lib/zot/context.ex`): Manages parsing state including input/output values, path tracking for nested structures, issue collection, and effects pipeline execution.

- **`Zot.Issue`** (`lib/zot/issue.ex`): Error representation with path, message templating, and Exception implementation.

### Type System

Each type in `lib/zot/type/` follows a consistent pattern:

1. **Uses `Zot.Template`**: The `deftype` macro generates struct definition and `new/1` constructor
2. **Implements `Zot.Type` protocol**: Provides `parse/3` for validation logic and `json_schema/1` for schema generation
3. **Uses `Zot.Commons`**: Shared validation helpers like `validate_type/2`, `validate_length/2`, `validate_number/2`

Available types: `boolean`, `date_time`, `decimal`, `email`, `enum`, `float`, `integer`, `list`, `literal`, `map`, `number`, `numeric`, `phone`, `record`, `string`, `union`, `uri`, `uuid`

### Effects Pipeline

Types support an effects pipeline (stored in `type.effects`) that runs after successful parsing:
- **`:transform`** - Modifies the output value
- **`:refine`** - Custom validation that can return boolean, `:ok/:error`, or a Context

### Coercion

When `coerce: true` is passed to `Z.parse/3`, types can convert from related types (e.g., `"true"` → `true` for booleans, `"42"` → `42` for integers).

### Map Types

- `Z.map/1` - Strips unknown fields
- `Z.strict_map/1` - Errors on unknown fields
- `Z.record/1` - String-keyed maps with typed values
- `Z.partial/1` - Makes all fields optional and drops nil values
