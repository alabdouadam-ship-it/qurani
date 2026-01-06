
import sqlite3

def verify():
    db_path = 'e:/Flutter/Qurani/assets/data/quran.db'
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("SELECT text_english FROM ayah WHERE id = 1")
    text = cursor.fetchone()[0]
    print(f"Verse 1 English: {text}")
    
    conn.close()

if __name__ == '__main__':
    verify()
