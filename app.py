from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

status = "Offline"
balance = 0.0

@app.route("/")
def home():
    return jsonify({"message": "KillerTrade API is live!"})

@app.route("/api", methods=["POST"])
def update_status():
    global status, balance
    status = request.form.get("status", status)
    balance = float(request.form.get("balance", balance))
    return jsonify({"message": "Updated", "status": status, "balance": balance})

@app.route("/api", methods=["GET"])
def get_status():
    return jsonify({"status": status, "balance": balance})
