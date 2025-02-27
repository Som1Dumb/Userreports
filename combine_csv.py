import pandas as pd
import glob
import os

# Path where CSV files are stored (update as necessary)
csv_folder_path = './generated_csv_files/'

# Output file name
output_file = 'merged_output.csv'

# Get list of CSV files
csv_files = glob.glob(os.path.join(csv_folder_path, '*.csv'))

# List to store dataframes
dfs = []

# Read and store dataframes
for file in csv_files:
    df = pd.read_csv(file)
    df.columns = df.columns.str.strip().str.lower().str.replace(' ', '_')  # standardize headers
    dfs.append(df)

# Merge dataframes, aligning columns
merged_df = pd.concat(dfs, ignore_index=True, sort=False)

# Save merged CSV
merged_df.to_csv(output_file, index=False)

print(f"Merged CSV created at: {output_file}")
