from flask_cors import CORS

from flask import Flask, jsonify

import weaviate
import json


app = Flask(__name__)

@app.route('/hello', methods=['GET'])
def hello():
    return jsonify({"message": "Hello, Swift!"})

@app.route('/test', methods=['GET'])
def test():
    client = weaviate.Client(
        url = "https://some-endpoint.weaviate.network",  # Replace with your endpoint
        auth_client_secret=weaviate.AuthApiKey(api_key="YOUR-WEAVIATE-API-KEY"),  # Replace w/ your Weaviate instance API key
        additional_headers = {
            "X-OpenAI-Api-Key": "YOUR-OPENAI-API-KEY"  # Replace with your inference API key
        }
    )

if __name__ == '__main__':
    app.run(debug=True)

CORS(app)
