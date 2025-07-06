# Stage 1: Builder - Install all Python dependencies, uv, and the playwright Python package
# We keep this stage lean to build Python packages efficiently.
FROM python:3.11-slim as builder

# Set common environment variables for the builder stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory for the builder stage
WORKDIR /app

# Install minimal system dependencies required for building Python packages.
RUN apt-get update -qq && apt-get install -y \
    ca-certificates \
    unzip \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Copy your requirements.txt for initial Python dependencies
COPY requirements.txt .

# Upgrade pip.
RUN pip install --upgrade pip

# Install main Python dependencies from requirements.txt.
# Ensure Playwright is in requirements.txt (e.g., playwright==1.52.0)
RUN --mount=type=cache,target=/root/.cache/pip_reqs,sharing=locked,id=pip-reqs-cache \
    pip install -r requirements.txt

# Install 'uv' using pip.
RUN --mount=type=cache,target=/root/.cache/uv_uv,sharing=locked,id=uv-uv-cache \
    pip install uv

# IMPORTANT: Ensure 'uv' CLI is in the PATH (playwright CLI will be in the final image)
ENV PATH="/usr/local/bin:/root/.local/bin:$PATH"

# Stage 2: Final - Create the runtime image using a Playwright base image
# This image already includes all browser binaries and their system dependencies.
FROM mcr.microsoft.com/playwright/python:v1.52.0-jammy

# Set common environment variables for the final stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# Playwright images usually set PATH correctly, but good to be explicit for other tools
ENV PATH="/usr/local/bin:/root/.local/bin:$PATH"

# Set the working directory for the final stage
WORKDIR /app

# Copy all installed Python packages from the builder stage.
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

# Copy the 'uv' CLI executable from the builder stage.
# Playwright CLI is already present in the base image.
COPY --from=builder /usr/local/bin/uv /usr/local/bin/uv

# NOTE: We no longer need to copy /root/.cache/ms-playwright/
# as the Playwright base image already has the browsers installed.

# Copy your application source code last.
COPY . .

# Expose the port your FastAPI application listens on
EXPOSE 8000

# Command to run your FastAPI application with Uvicorn.
CMD ["sh", "-c", "python -m uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]