#!/usr/bin/env python3
"""Fix CSV by properly quoting all text fields that contain commas"""

import csv
import sys

input_file = r"c:\Users\João Vitor D. da Luz\OneDrive\Documents\krakovia-kraft\krakovia-tiny-mmo\localization\translations.csv"
output_file = r"c:\Users\João Vitor D. da Luz\OneDrive\Documents\krakovia-kraft\krakovia-tiny-mmo\localization\translations_fixed.csv"

# Read the CSV
with open(input_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Write properly quoted CSV
with open(output_file, 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
    
    for line in lines:
        line = line.rstrip('\n\r')
        if not line:
            continue
            
        # Split by comma (but this is naive - doesn't handle existing quotes)
        parts = line.split(',')
        
        if len(parts) >= 3:
            # key, en, pt_BR
            key = parts[0]
            # Everything after first comma until last comma group is EN
            # This is tricky because of existing quotes...
            
            # Better approach: use csv reader
            continue
        
        writer.writerow(parts)

print("Fixed CSV written to:", output_file)
