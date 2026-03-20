#!/usr/bin/env python3
import os

files_to_fix = [
    'scripts/reading/track_generator/TrackGenerator.gd',
    'scripts/reading/track_segments/CurveSegment.gd',
    'scripts/reading/triggers/ReadingFinishGateTrigger.gd',
    'scripts/reading/triggers/ReadingObstacleTrigger.gd',
    'scripts/reading/triggers/ReadingPickupTrigger.gd'
]

for filepath in files_to_fix:
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Remove trailing whitespace from each line but keep newlines
        fixed_lines = [line.rstrip() + '\n' if line.rstrip() else '\n' for line in lines]
        # Remove trailing newlines at the end of file (last line should not have newline)
        if fixed_lines and fixed_lines[-1] == '\n':
            fixed_lines[-1] = fixed_lines[-1].rstrip() + '\n'
        
        with open(filepath, 'w', encoding='utf-8', newline='') as f:
            f.writelines(fixed_lines)
        print(f'Fixed: {filepath}')
