# Python Skyscanner (FastAPI + LLM + Browser Automation)

A production-ready FastAPI application that uses LLMs and browser automation to search for flights and return the cheapest option based on a natural language prompt. The app leverages `langchain`, `browser_use`, and OpenAI models to parse user queries and scrape flight data.

## Features

- Accepts natural language flight search prompts (e.g., "Find me a flight from Singapore to Tokyo next Friday, return Sunday")
- Uses LLMs to parse and structure flight search details
- Automates browser actions to search for flights and extract results
- Returns the cheapest flight with airline, times, stops, and price
- Production-ready Docker image

## Requirements

- Python 3.11+
- Docker (for containerized deployment)
- OpenAI API key (for LLM)
- Chrome/Chromium (if using browser automation in Docker, see Dockerfile comments)
- The `browser_use` package (see below)

## Setup

### 1. Clone the repository

```bash
git clone <your-repo-url>
cd python-skyscanner
```

### 2. Create `.env` file

Add your environment variables (e.g., OpenAI API key):

```
OPENAI_API_KEY=your-key-here
```

### 3. Install dependencies (for local development)

```bash
pip install -r requirements.txt
```

### 4. Run the app locally

```bash
uvicorn app:app --reload
```

The API will be available at [http://localhost:8000](http://localhost:8000).

## Docker Usage

### Build the Docker image

```bash
docker build -t python-skyscanner .
```

### Run the Docker container

```bash
docker run -p 8000:8000 --env-file .env python-skyscanner
```

## API Usage

### POST `/flights`

Request body:
```json
{
  "prompt": "Find me a flight from Singapore to Tokyo next Friday, return Sunday"
}
```

Response:
```json
{
  "airline": "Singapore Airlines",
  "departure_time": "10:00 AM",
  "arrival_time": "5:30 PM",
  "flight_duration": "7h 30m",
  "number_of_stops": 0,
  "price": "SGD 500"
}
```

## Notes

- The `browser_use` package is required and may not be available on PyPI. If it's a local or private package, follow the instructions in the Dockerfile to add it to your image.
- If running in Docker, you may need to install Chrome/Chromium and drivers. See the commented lines in the Dockerfile for guidance.
- This project uses FastAPI and uvicorn for production-ready ASGI serving.

## License

MIT
