import os

from dotenv import load_dotenv
from fastapi import FastAPI
from openai import OpenAI
from pydantic import BaseModel


load_dotenv()


app = FastAPI()


client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key=os.getenv("OPENROUTER_API_KEY")
)


class AssistantRequest(BaseModel):

    text: str

    image: str | None = None


@app.post("/assistant")
def assistant(request: AssistantRequest):

    print("TEXT:", request.text)

    content = [
        {
            "type": "text",
            "text": request.text
        }
    ]

    if request.image:

        print(
            "IMAGE BASE64 LENGTH:",
            len(request.image)
        )

        image_url = (
            "data:image/png;base64,"
            + request.image
        )

        content.append(
            {
                "type": "image_url",
                "image_url": {
                    "url": image_url
                }
            }
        )

    try:

        response = client.chat.completions.create(

            model="openrouter/free",

            messages=[
                {
                    "role": "user",
                    "content": content
                }
            ]
        )

        answer = response.choices[0].message.content

        print(
            "LLM RESPONSE:",
            answer
        )

        return {
            "response": answer
        }

    except Exception as error:

        print(
            "OPENROUTER ERROR:",
            error
        )

        return {
            "response": "Sorry, I couldn't process that request."
        }