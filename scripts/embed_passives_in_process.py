#!/usr/bin/env python3
"""
Embed complete passive abilities data into the passive-ability-engine.lua process
Replaces the placeholder data with full 900+ species data
"""

import re

def embed_passives_in_process():
    """Embed full passive abilities data into process file"""

    # Read the converted passives data
    with open("processes/data/starter-passive-abilities.lua", 'r') as f:
        passives_content = f.read()

    # Extract just the table content (without local declaration and return)
    match = re.search(r'local starterPassiveAbilities = \{(.*?)\}', passives_content, re.DOTALL)
    if not match:
        print("ERROR: Could not extract passives data")
        return

    passives_data = match.group(1).strip()

    # Read the process file
    with open("processes/passive-ability-engine.lua", 'r') as f:
        process_content = f.read()

    # Find and replace the starterPassiveAbilities table
    pattern = r'(local starterPassiveAbilities = \{)(.*?)(\n\})'
    replacement = r'\1\n    ' + passives_data.replace('\n', '\n    ') + r'\3'

    updated_content = re.sub(pattern, replacement, process_content, flags=re.DOTALL)

    # Write back
    with open("processes/passive-ability-engine.lua", 'w') as f:
        f.write(updated_content)

    print("✓ Embedded full passive abilities data into passive-ability-engine.lua")

if __name__ == "__main__":
    embed_passives_in_process()