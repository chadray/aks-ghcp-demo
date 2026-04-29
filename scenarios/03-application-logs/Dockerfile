FROM python:3.11-slim

WORKDIR /app

# Copy application
COPY app.py .

# Expose port
EXPOSE 8080

# Set Python to run in unbuffered mode for better logging
ENV PYTHONUNBUFFERED=1
ENV LOG_LEVEL=INFO

# Run the application
CMD ["python3", "app.py"]
