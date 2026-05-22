FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all backend modules (app imports db, metrics, deployer)
COPY app.py db.py metrics.py deployer.py ./

EXPOSE 5000

CMD ["python", "app.py"]
