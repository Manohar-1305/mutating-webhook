FROM python:3.11-slim
WORKDIR /app
RUN pip install flask kubernetes
COPY app.py /app/app.py
EXPOSE 8443
CMD ["python", "/app/app.py"]
