FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src ./src

RUN useradd --create-home karta
USER karta

EXPOSE 8000

CMD ["uvicorn", "src.infrastructure.main:app", "--host", "0.0.0.0", "--port", "8000"]
