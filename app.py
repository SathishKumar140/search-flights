from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
import asyncio
from main import get_flight_details, search_flight, llm

app = FastAPI()

class FlightRequest(BaseModel):
    prompt: str
    webhook_url: Optional[str] = None

class FlightResponse(BaseModel):
    airline: str
    departure_time: str
    arrival_time: str
    flight_duration: str
    number_of_stops: int
    price: str

from fastapi import BackgroundTasks

@app.post("/flights")
async def get_cheapest_flight(flight_request: FlightRequest, background_tasks: BackgroundTasks):
    """
    Searches for flights based on the user prompt.
    If webhook_url is provided, runs in background and posts result to webhook.
    Otherwise, returns the result directly.
    """
    details = get_flight_details(flight_request.prompt)
    print(f"Extracted flight details: {details}")
    if not details:
        raise HTTPException(status_code=400, detail="Could not parse flight details from prompt")

    if flight_request.webhook_url:
        background_tasks.add_task(process_flight_search, flight_request, details)
        return {"message": "Flight search started. Results will be sent to the webhook when ready."}

    flight_details = await search_flight(details)
    if not flight_details:
        raise HTTPException(status_code=404, detail="No flights found")
    
    prompt = f"Given the following flight details, predict the cheapest flight: {flight_details}"
    response = llm.invoke(prompt)
    cheapest_flight = response.content

    # Parse the cheapest flight details from the flight_details JSON
    try:
        # Use correct keys from Flights model
        # Filter out flights with invalid or null prices
        valid_flights = [
            f for f in flight_details['flights']
            if f.get('price') and f['price'].lower() != 'null'
        ]
        if not valid_flights:
            raise HTTPException(status_code=404, detail="No flights with valid prices found")
        import re
        cheapest_flight = min(
            valid_flights,
            key=lambda x: float(re.search(r'(\d[\d,]*)+', x['price']).group(0).replace(',', '')) if re.search(r'(\d[\d,]*)+', x['price']) else float('inf')
        )
        airlines = cheapest_flight.get('airlines', '')
        departure_time = cheapest_flight.get('departure_time', '')
        arrival_time = cheapest_flight.get('arrival_time', '')
        flight_duration = cheapest_flight.get('flight_duration', '')
        stops_str = cheapest_flight.get('stops', '')
        price = cheapest_flight.get('price', '')

        # Parse number_of_stops from stops_str
        if stops_str.lower() == "nonstop":
            number_of_stops = 0
        else:
            import re
            match = re.search(r"(\d+)", stops_str)
            number_of_stops = int(match.group(1)) if match else 0

        return FlightResponse(
            airline=airlines,
            departure_time=departure_time,
            arrival_time=arrival_time,
            flight_duration=flight_duration,
            number_of_stops=number_of_stops,
            price=price
        )
    except Exception as e:
        print(f"Error parsing cheapest flight details: {e}")
        raise HTTPException(status_code=500, detail="Could not parse cheapest flight details")

# Background task function to process the flight search and POST result to webhook
def process_flight_search(flight_request: FlightRequest, details):
    import requests

    try:
        # Run the async search_flight in a sync context
        flight_details = asyncio.run(search_flight(details))
        if not flight_details:
            result = {"error": "No flights found"}
        else:
            prompt = f"Given the following flight details, predict the cheapest flight: {flight_details}"
            response = llm.invoke(prompt)
            cheapest_flight = response.content
            # Parse the cheapest flight details from the flight_details JSON
            valid_flights = [
                f for f in flight_details['flights']
                if f.get('price') and f['price'].lower() != 'null'
            ]
            if not valid_flights:
                result = {"error": "No flights with valid prices found"}
            else:
                cheapest_flight = min(
                    valid_flights,
                    key=lambda x: float(x['price'].replace('SGD ', '').replace(',', ''))
                )
                airlines = cheapest_flight.get('airlines', '')
                departure_time = cheapest_flight.get('departure_time', '')
                arrival_time = cheapest_flight.get('arrival_time', '')
                flight_duration = cheapest_flight.get('flight_duration', '')
                stops_str = cheapest_flight.get('stops', '')
                price = cheapest_flight.get('price', '')

                # Parse number_of_stops from stops_str
                if stops_str.lower() == "nonstop":
                    number_of_stops = 0
                else:
                    import re
                    match = re.search(r"(\d+)", stops_str)
                    number_of_stops = int(match.group(1)) if match else 0

                result = {
                    "airline": airlines,
                    "departure_time": departure_time,
                    "arrival_time": arrival_time,
                    "flight_duration": flight_duration,
                    "number_of_stops": number_of_stops,
                    "price": price
                }
        # POST the result to the webhook
        requests.post(flight_request.webhook_url, json=result, timeout=10)
    except Exception as e:
        print(f"Error in process_flight_search: {e}")
        # Optionally, POST error to webhook
        try:
            requests.post(flight_request.webhook_url, json={"error": str(e)}, timeout=10)
        except Exception as post_err:
            print(f"Error posting error to webhook: {post_err}")
