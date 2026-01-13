FROM python:3.11-slim

WORKDIR /app

# Install system dependencies (e.g. for asyncpg/psycopg2 building if needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

# Expose port (Cloud Run/Compute Engine defaults often to 8080 or 8000)
EXPOSE 8000

# Start command
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
