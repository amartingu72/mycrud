conda activate mycrud
pip install fastapi uvicorn sqlalchemy psycopg2-binary
uvicorn main:app --reload --url 0.0.0.0 --port 8000


docker run --name mycruddb -e POSTGRES_PASSWORD=kkkk -d postgres
The default postgres user and database are created in the entrypoint with initdb