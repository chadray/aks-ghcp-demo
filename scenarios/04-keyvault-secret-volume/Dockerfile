FROM python:3.11-slim

WORKDIR /app

# Copy application
COPY app.py .

# Set Python to run in unbuffered mode for better logging
ENV PYTHONUNBUFFERED=1

# Run the application
CMD ["python3", "app.py"]
