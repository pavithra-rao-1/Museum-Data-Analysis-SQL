import os
import pandas as pd
import pyodbc

# Configuration details
server = 'LENOVO'  # Replace with your server name
database = 'paintings'  # Replace with your database name
csv_folder_path = r'file_folder'  # Use raw string to avoid escape issues

# Establish connection to MS SQL Server
try:
    conn = pyodbc.connect(
        f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={server};DATABASE={database};Trusted_Connection=yes"
    )
    cursor = conn.cursor()
    print("Database connection successful!")
except pyodbc.Error as e:
    print(f"Error connecting to the database: {e}")
    exit()

# Iterate over CSV files in the folder
for file in os.listdir(csv_folder_path):
    if file.endswith('.csv'):
        file_path = os.path.join(csv_folder_path, file)
        table_name = os.path.splitext(file)[0]  # Use file name without extension as the table name

        # Load CSV into a DataFrame
        try:
            df = pd.read_csv(file_path)
            print(f"Processing file: {file}")
        except Exception as e:
            print(f"Error reading {file}: {e}")
            continue

        # Create table if it does not exist
        create_table_query = f"CREATE TABLE {table_name} ("
        for col in df.columns:
            create_table_query += f"[{col}] NVARCHAR(MAX), "  # Assuming NVARCHAR for all columns
        create_table_query = create_table_query.rstrip(', ') + ')'

        try:
            cursor.execute(f"IF OBJECT_ID('{table_name}', 'U') IS NULL BEGIN {create_table_query} END")
            print(f"Table {table_name} created or already exists.")
        except Exception as e:
            print(f"Error creating table {table_name}: {e}")
            continue

        # Insert data into the table
        try:
            for _, row in df.iterrows():
                placeholders = ', '.join(['?'] * len(row))  # Create placeholders for the values
                columns = ', '.join(f"[{col}]" for col in df.columns)  # Get column names from the DataFrame
                sql = f"INSERT INTO {table_name} ({columns}) VALUES ({placeholders})"
                cursor.execute(sql, tuple(row))
            print(f"Data from {file} inserted into table {table_name} successfully.")
        except Exception as e:
            print(f"Error inserting data into table {table_name}: {e}")
            continue

# Commit the transaction
try:
    conn.commit()
    print("All changes committed successfully.")
except Exception as e:
    print(f"Error during commit: {e}")

# Close the connection
cursor.close()
conn.close()
print("All files have been processed successfully!")
