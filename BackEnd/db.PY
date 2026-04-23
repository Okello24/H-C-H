import psycopg2

def get_db():
    return psycopg2.connect(
        host="localhost",
        database="HCHdatabase",
        user="postgres",
        password="Victic24@",
        port="5432"
    )