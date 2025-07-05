import json
from dotenv import load_dotenv
from browser_use import BrowserSession, Agent, Controller
from browser_use.llm.google import chat
from langchain_openai import ChatOpenAI
from browser_use.llm import ChatOpenAI as ChatOpenAIBrowserUse
from langgraph.prebuilt import create_react_agent
from typing import List
from pydantic import BaseModel

llm = ChatOpenAI(
        model="gpt-4.1",
)

load_dotenv()



class Flight(BaseModel):
    price: str
    flight_duration: str
    stops: str
    airlines: str
    departure_time: str
    arrival_time: str
    flight_number: str
    layover_details: str  # Consider a more structured type if needed


class Flights(BaseModel):
    flights: List[Flight]


def getCurrentDate():
    """
    Returns the current date in the format YYYY-MM-DD.
    """
    from datetime import datetime
    return datetime.now().strftime("%Y-%m-%d")

def get_flight_details(prompt):
    """
    Uses the Google AI API to parse a natural language prompt and return structured flight details.
    """
    tools = [getCurrentDate]
    agent_executor = create_react_agent(llm, tools)
    input_message = [{"role": "system", "content": 'Parse the following flight search query and return a JSON object with the keys "origin" as code, "destination" as code, "departureDate" and "returnDate" use getCurrentDate tool to get system date as base and calculate future dates.' }, {"role": "user", "content": prompt}]
    response = agent_executor.invoke({"messages": input_message})
    last_ai_message = response["messages"][-1]
    cleaned_text = last_ai_message.content.replace("```json\n", "").replace("```", "").strip()
    import re

    match = re.search(r"[\s\S]*?(\{[\s\S]*?\})[\s\S]*?", cleaned_text)
    if match:
        json_string = match.group(1)
        json_string = re.sub(r"//.*", "", json_string)
    else:
        json_string = ""
    try:
        return json.loads(json_string)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON from AI response: {e}")
        return None


async def search_flight(flight_details):
    """
    Uses browser-use to search for a flight on Skyscanner with the given details.
    """
    origin = flight_details["origin"]
    destination = flight_details["destination"]
    departure_date = flight_details["departureDate"]
    return_date = flight_details["returnDate"]

    url = f"https://www.google.com/travel/flights/search"


    browser_session = BrowserSession(
        headless=True,
        chromium_sandbox=False,
        user_data_dir=None
    )

    browserUseLLM = ChatOpenAIBrowserUse(
        model="gpt-4.1",
    )

    controller = Controller(output_model=Flights)

    task = f"First, **navigate to the specified URL**: `{url}`. Upon loading, locate the 'Where from' field and input {origin}, then select the suggested origin from the autocomplete list.  once selected choose another field, locate the 'Where to' field and input {destination}, and select the suggested destination., choose the `departure date` `{departure_date}` into the respective calendar and perform selection in the calender, and the `return date` `{return_date}` into its corresponding field (if this is a one-way search, locate and **select the 'One-Way' radio button or checkbox** and **omit inputting the return date**). After all fields are populated, **locate and click the primary 'Search Flights' or 'Find Flights' button**. Once the flight results page has fully loaded and all dynamic content (like loading spinners) has settled, **iterate through each individual flight listing** displayed. For each listing, **extract the following information**: the `price` (including currency, e.g., 'SGD 500'), the `total flight duration` (e.g., '7h 30m'), the `number of stops` (e.g., 'Nonstop', '1 stop', '2 stops'), the `operating airline(s)` (e.g., 'Singapore Airlines' or 'Singapore Airlines, SilkAir'), the `scheduled departure time` (e.g., '10:00 AM'), the `scheduled arrival time` (e.g., '5:30 PM'), the `flight number(s)` (e.g., 'SQ123', 'SQ123 / MI456' – if available), and for flights with stops, `detailed layover information` including the `layover location` (e.g., 'Hong Kong (HKG)') and `layover duration` (e.g., '2h 00m') for each segment. Finally, **compile all extracted flight details into a JSON array**, where each object in the array represents a single flight, adhering to the specified keys (price, flight_duration, stops, airlines, departure_time, arrival_time, flight_number, layover_details)."
    agent = Agent(
        task=task,
        llm=browserUseLLM,
        browser_session=browser_session,
        controller=controller,
    )

    history = await agent.run()
    flight_details = history.final_result()
    print(f"Content of flight_details: {flight_details}")
    try:
        flight_details_json = json.loads(flight_details)
        return flight_details_json
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON: {e}")
        return None
