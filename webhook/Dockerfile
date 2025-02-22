FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY webhook.py .
COPY tls /tls  

CMD ["python", "webhook.py"]
