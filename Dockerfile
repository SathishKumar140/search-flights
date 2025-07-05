# Stage 1: Builder - Install all Python dependencies, uv, and browser binaries
FROM python:3.11-slim as builder

# Set common environment variables for the builder stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory for the builder stage
WORKDIR /app

# Install minimal system dependencies required for Playwright and general use.
RUN apt-get update -qq && apt-get install -y \
    ca-certificates \
    fonts-liberation \
    # Ensure unzip is installed, as Playwright downloads are ZIP archives
    unzip \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Copy your requirements.txt for initial Python dependencies
COPY requirements.txt .

# Upgrade pip.
RUN pip install --upgrade pip

# Install main Python dependencies from requirements.txt.
RUN --mount=type=cache,target=/root/.cache/pip_reqs,sharing=locked,id=pip-reqs-cache \
    pip install -r requirements.txt

# Install 'uv' using pip.
RUN --mount=type=cache,target=/root/.cache/pip_uv,sharing=locked,id=pip-uv-cache \
    pip install uv

# IMPORTANT: Ensure 'uv' and 'playwright' CLI are in the PATH.
ENV PATH="/usr/local/bin:/root/.local/bin:$PATH"

# Now, use 'uv' to install playwright and patchright.
RUN --mount=type=cache,target=/root/.cache/uv_deps,sharing=locked,id=uv-deps-cache \
    uv pip install --system playwright==1.52.0 patchright==1.52.5

# Install Chromium browser binary and its system dependencies using Playwright's installer.
# This step downloads and extracts the browser.
# Adding more logging and explicit checks.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-cache \
    --mount=type=cache,target=/root/.cache/ms-playwright,sharing=locked,id=playwright-browser-cache \
    apt-get update -qq && \
    echo "--- Starting playwright install ---" && \
    playwright install --with-deps --no-shell chromium || (echo "ERROR: playwright install command failed!" && exit 1) && \
    echo "--- playwright install command completed. Verifying cache directory. ---" && \
    # Explicitly check if the main cache directory exists
    test -d "/root/.cache/ms-playwright" || (echo "CRITICAL ERROR: /root/.cache/ms-playwright does not exist after install!" && ls -la /root/.cache/ && exit 1) && \
    # Explicitly check for the browser-specific directory within the cache
    test -d "/root/.cache/ms-playwright/chromium-1169" || (echo "CRITICAL ERROR: Chromium 1169 directory not found in cache!" && ls -la /root/.cache/ms-playwright/ && exit 1) && \
    echo "--- Playwright cache directory confirmed to exist! ---" && \
    echo "Contents of /root/.cache/ms-playwright/:" && ls -la /root/.cache/ms-playwright/ && \
    echo "Contents of /root/.cache/ms-playwright/chromium-1169/:" && ls -la /root/.cache/ms-playwright/chromium-1169/ && \
    echo "Size of Playwright cache:" && du -sh /root/.cache/ms-playwright/ && \
    rm -rf /var/lib/apt/lists/*


# Stage 2: Final - Create a smaller runtime image
FROM python:3.11-slim

# Set common environment variables for the final stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# CRITICAL: Ensure PATH is also set correctly in the final stage.
ENV PATH="/usr/local/bin:/root/.local/bin:$PATH"

# Set the working directory for the final stage
WORKDIR /app

# Copy all installed Python packages from the builder stage.
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

# Copy the 'uv' and 'playwright' CLI executables from the builder stage.
COPY --from=builder /usr/local/bin/uv /usr/local/bin/uv
COPY --from=builder /usr/local/bin/playwright /usr/local/bin/playwright

# CRITICAL: Copy the Playwright browser binaries from the builder stage to the final image.
COPY --from=builder /root/.cache/ms-playwright /root/.cache/ms-playwright

# Copy your application source code last.
COPY . .

# Expose the port your FastAPI application listens on
EXPOSE 8000

# Command to run your FastAPI application with Uvicorn.
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]