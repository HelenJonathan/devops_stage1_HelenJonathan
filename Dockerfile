# Use official Python image
FROM python:3.10-slim

WORKDIR /app

COPY . /app

RUN pip install --no-cache-dir flask

EXPOSE 8000

# Simple Flask app
CMD ["python3", "-m", "flask", "--app", "app", "run", "--host=0.0.0.0", "--port=8000"]
