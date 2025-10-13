#!/usr/bin/env python3
"""Extract egg moves from TypeScript file and convert to Lua format."""

import re
import sys

def load_enum_values(file_path, enum_prefix):
    """Load enum values from TypeScript enum file."""
    enum_values = {}
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    current_value = 0
    for line in lines:
        # Match enum entry with explicit value
        match = re.match(r'\s*(\w+)\s*=\s*(\d+),?', line)
        if match:
            name = match.group(1)
            value = int(match.group(2))
            enum_values[name] = value
            current_value = value + 1
        else:
            # Match enum entry without value (auto-increment)
            match = re.match(r'\s*(\w+),?\s*$', line)
            if match:
                name = match.group(1)
                enum_values[name] = current_value
                current_value += 1
    
    return enum_values

def extract_egg_moves(file_path):
    """Extract egg moves from TypeScript file."""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Find the speciesEggMoves object
    pattern = r'\[SpeciesId\.(\w+)\]:\s*\[(.*?)\]'
    matches = re.findall(pattern, content)
    
    egg_moves = {}
    for species, moves in matches:
        # Clean up move list
        move_list = re.findall(r'MoveId\.(\w+)', moves)
        if move_list:
            egg_moves[species] = move_list
    
    return egg_moves

def convert_to_lua_with_ids(egg_moves, species_ids, move_ids):
    """Convert egg moves to Lua format with proper IDs."""
    lines = ["local EggMoveDatabase = {"]
    lines.append("    -- Species ID -> {Move IDs}")
    lines.append("    -- Generated from TypeScript egg-moves.ts")
    
    for species in sorted(egg_moves.keys()):
        if species not in species_ids:
            continue
            
        species_id = species_ids[species]
        moves = egg_moves[species]
        
        # Convert move names to IDs
        move_id_list = []
        for move in moves:
            if move in move_ids:
                move_id_list.append(str(move_ids[move]))
        
        if move_id_list:
            move_str = ", ".join(move_id_list)
            comment = f" -- {species}: " + ", ".join(moves[:2])
            if len(moves) > 2:
                comment += f" (+{len(moves)-2} more)"
            lines.append(f'    [{species_id}] = {{{move_str}}},{comment}')
    
    lines.append("}")
    lines.append("")
    lines.append(f"-- Total species with egg moves: {len([s for s in egg_moves if s in species_ids])}")
    
    return "\n".join(lines)

def convert_to_lua_with_names(egg_moves):
    """Convert egg moves to Lua format with string names as fallback."""
    lines = ["local EggMoveDatabase = {"]
    lines.append("    -- Species Name -> {Move Names}")
    lines.append("    -- String-based fallback format")
    
    for species in sorted(egg_moves.keys()):
        moves = egg_moves[species]
        move_str = ", ".join([f'"{move}"' for move in moves])
        lines.append(f'    {species} = {{{move_str}}},')
    
    lines.append("}")
    lines.append("")
    lines.append(f"-- Total species with egg moves: {len(egg_moves)}")
    
    return "\n".join(lines)

if __name__ == "__main__":
    try:
        # Load species IDs
        species_ids = load_enum_values("typescript-reference/src/enums/species-id.ts", "SpeciesId")
        
        # Load move IDs
        move_ids = load_enum_values("typescript-reference/src/enums/move-id.ts", "MoveId")
        
        # Extract egg moves
        egg_moves = extract_egg_moves("typescript-reference/src/data/balance/egg-moves.ts")
        
        # Convert to Lua with IDs
        lua_code = convert_to_lua_with_ids(egg_moves, species_ids, move_ids)
        
    except Exception as e:
        # Fallback to string-based format
        egg_moves = extract_egg_moves("typescript-reference/src/data/balance/egg-moves.ts")
        lua_code = convert_to_lua_with_names(egg_moves)
    
    print(lua_code)