from flask_cors import CORS

from flask import Flask, jsonify

import weaviate
import json

from dotenv import load_dotenv

import os



load_dotenv()

OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
WEAVIATE_KEY = os.getenv('WEAVIATE_KEY')



app = Flask(__name__)

@app.route('/hello', methods=['GET'])
def hello():
    return jsonify({"message": "Hello, Swift!"})

@app.route('/test', methods=['GET'])
def test():
    client = weaviate.Client(
        url = "https://for-tab-ta75ybw4.weaviate.network",  # Replace with your endpoint
        auth_client_secret=weaviate.AuthApiKey(api_key=WEAVIATE_KEY),  # Replace w/ your Weaviate instance API key
        additional_headers = {
            "X-OpenAI-Api-Key": OPENAI_API_KEY  # Replace with your inference API key
        }
    )

if __name__ == '__main__':
    app.run(debug=True)

CORS(app)
