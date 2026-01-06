
import sqlite3
import json
import os

def update_db():
    json_path = 'e:/Flutter/Qurani/assets/data/quran-english.json'
    db_path = 'e:/Flutter/Qurani/assets/data/quran.db'
    
    print(f"Loading JSON from {json_path}...")
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    print(f"Connecting to database at {db_path}...")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    surahs = data['data']['surahs']
    count = 0
    
    print("Updating database...")
    try:
        cursor.execute("BEGIN TRANSACTION")
        
        for surah in surahs:
            ayahs = surah['ayahs']
            for ayah in ayahs:
                id_val = ayah['number'] # Global ID
                text = ayah['text']
                
                cursor.execute(
                    "UPDATE ayah SET text_english = ? WHERE id = ?",
                    (text, id_val)
                )
                count += 1
                
        conn.commit()
        print(f"Successfully updated {count} verses.")
        
    except Exception as e:
        conn.rollback()
        print(f"Error updating database: {e}")
    finally:
        conn.close()

if __name__ == '__main__':
    update_db()
