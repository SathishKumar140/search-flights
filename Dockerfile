# Stage 1: Builder - Install all dependencies, Python packages, and browser binaries
FROM python:3.11-slim as builder

# Set common environment variables for the builder stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory for the builder stage
WORKDIR /app

# Install minimal system dependencies required for Playwright.
# Playwright's 'install --with-deps' will handle most browser-specific dependencies.
# -qq for quiet update
# --no-install-recommends to keep image size down
RUN apt-get update -qq && apt-get install -y \
    ca-certificates \
    fonts-liberation \
    # You might need these if your specific base image or app requires them, e.g., for curl downloads
    # curl \
    # git \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Copy your requirements.txt for initial Python dependencies
# This allows Docker to cache this layer if requirements.txt doesn't change
COPY requirements.txt .

# Install pip upgrade
RUN pip install --upgrade pip

# Install requirements.txt using pip (good for layering)
RUN pip install -r requirements.txt

# Install 'uv' and set PATH for the current shell, then use 'uv'.
# This ensures 'uv' is found within the same command context.
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked,id=pip-cache-uv-install \
    pip install uv && \
    # Add uv's install location to PATH for this command's shell context
    # /root/.local/bin is common for pip user installs in slim images
    export PATH="/root/.local/bin:$PATH" && \
    # Optional: Debugging step to confirm uv is found
    which uv && \
    echo "PATH after uv install: $PATH" && \
    # Now use uv to install playwright and patchright
    --mount=type=cache,target=/root/.cache/uv,sharing=locked,id=uv-cache-deps \
    uv pip install --system playwright==1.52.0 patchright==1.52.5

# Install Chromium browser binary and its system dependencies using Playwright's installer.


# Stage 2: Final - Create a smaller runtime image
FROM python:3.11-slim

# Set common environment variables for the final stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# Crucial: Ensure PATH is set correctly in the final stage too
ENV PATH="/root/.local/bin:$PATH"

# Set the working directory for the final stage
WORKDIR /app

# Copy installed Python packages from the builder stage.
# This brings over all Python libraries, including playwright and browser_use.
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

# Copy the 'uv' and 'playwright' CLI executables from the builder stage.
# They are installed by pip/uv into /root/.local/bin in the builder.
COPY --from=builder /root/.local/bin/uv /usr/local/bin/uv
COPY --from=builder /root/.local/bin/playwright /usr/local/bin/playwright

# --- THIS IS THE MOST CRITICAL STEP FOR YOUR ERROR ---
# Copy the Playwright browser binaries from the builder stage to the final image.
# The path must exactly match where playwright installed it in the builder stage.
COPY --from=builder /root/.cache/ms-playwright /root/.cache/ms-playwright

# Copy your application source code last to leverage Docker's build cache effectively.
# This ensures that changes to your code don't invalidate previous dependency layers.
COPY . .

# Expose the port your FastAPI application listens on
EXPOSE 8000

# Command to run your FastAPI application with Uvicorn.
# It uses the PORT environment variable if set (common in cloud deployments like Render/Koyeb)
# or defaults to 8000.
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]