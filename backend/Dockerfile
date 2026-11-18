FROM python:3.14-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY . .
RUN uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH"

RUN adduser -u 5678 --disabled-password --gecos "" appuser && chown -R appuser /app
USER appuser

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "-k", "uvicorn.workers.UvicornWorker", "presentation.app:app"]