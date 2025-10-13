#!/usr/bin/env python3
"""
Convert TypeScript passive abilities data to Lua format
Extracts starterPassiveAbilities from passives.ts and generates Lua table
"""

import re
import sys

def convert_passives_to_lua(ts_file_path, output_file_path):
    """Convert TypeScript passives to Lua format"""

    with open(ts_file_path, 'r') as f:
        content = f.read()

    # Extract the starterPassiveAbilities object
    match = re.search(r'export const starterPassiveAbilities: StarterPassiveAbilities = \{(.*?)\n\};', content, re.DOTALL)

    if not match:
        print("ERROR: Could not find starterPassiveAbilities in file")
        sys.exit(1)

    ts_data = match.group(1)

    # Convert TypeScript to Lua format
    lua_lines = []
    lua_lines.append("-- Auto-generated from TypeScript reference")
    lua_lines.append("-- Source: typescript-reference/src/data/balance/passives.ts")
    lua_lines.append("local starterPassiveAbilities = {")

    # Process each line
    for line in ts_data.split('\n'):
        line = line.strip()
        if not line or line.startswith('//'):
            continue

        # Convert SpeciesId.NAME to string key
        line = re.sub(r'\[SpeciesId\.(\w+)\]', r'["\1"]', line)

        # Convert AbilityId.NAME to string value
        line = re.sub(r'AbilityId\.(\w+)', r'"\1"', line)

        # Convert : to = for Lua syntax
        line = re.sub(r':\s*\{', ' = {', line)
        line = re.sub(r'(\d+):\s*"', r'[\1] = "', line)

        # Add comma after closing brace if missing
        if line.endswith('}') and not line.endswith('},'):
            line = line + ','

        lua_lines.append("    " + line)

    lua_lines.append("}")
    lua_lines.append("")
    lua_lines.append("return starterPassiveAbilities")

    # Write output
    with open(output_file_path, 'w') as f:
        f.write('\n'.join(lua_lines))

    print(f"✓ Converted {len(lua_lines)} lines to {output_file_path}")

if __name__ == "__main__":
    ts_file = "typescript-reference/src/data/balance/passives.ts"
    lua_file = "processes/data/starter-passive-abilities.lua"

    convert_passives_to_lua(ts_file, lua_file)