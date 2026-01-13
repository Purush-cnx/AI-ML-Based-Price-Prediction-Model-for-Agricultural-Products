
from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib, pandas as pd, datetime, requests

app = Flask(__name__)
CORS(app)

# === Load Models ===
crop_model = joblib.load(r"D:\FINAL PROJECT\MODEL\crop_recommendation_model.pkl")
price_model = joblib.load(r"D:\FINAL PROJECT\MODEL\price_model.pkl")
label = joblib.load(r"D:\FINAL PROJECT\MODEL\label_encoders.pkl")

# CROP RECOMMENDATION

@app.route("/predict_crop", methods=["POST"])
def predict_crop():
    data = request.get_json()
    N = float(data["N"]); P = float(data["P"]); K = float(data["K"]); ph = float(data["ph"])
    district = data["district"]

    # Weather API (or fallback)
    try:
        key = "1259050f0b8c4711bf2112234250610"
        w = requests.get(f"http://api.weatherapi.com/v1/current.json?key={key}&q={district}").json()["current"]
        temp, hum, rain = w["temp_c"], w["humidity"], w.get("precip_mm", 0)
    except:
        temp, hum, rain = 25, 60, 100

    # Season
    m = datetime.datetime.now().month
    if m in [6,7,8,9,10]: season = "kharif"
    elif m in [11,12,1,2]: season = "rabi"
    else: season = "summer"

    s = {"season_kharif": 0, "season_rabi": 0, "season_summer": 0}
    s[f"season_{season}"] = 1

    x = pd.DataFrame([{**{"N": N, "P": P, "K": K, "temperature": temp,
                          "humidity": hum, "ph": ph, "rainfall": rain}, **s}])
    for c in crop_model.feature_names_in_:
        if c not in x.columns: x[c] = 0
    x = x[crop_model.feature_names_in_]

    crop = crop_model.predict(x)[0]
    probs = crop_model.predict_proba(x)[0]
    top = pd.DataFrame({"crop": crop_model.classes_, "confidence": probs * 100}).sort_values("confidence", ascending=False).head(5)

    formatted_output = f"""
Recommended Crop: {crop}

Weather Details:
Temperature: {temp} °C
Humidity: {hum} %
Rainfall: {rain} mm
Season: {season.title()}

Top 5 Probable Crops:
"""
    for i, row in enumerate(top.itertuples(), 1):
        formatted_output += f"{i}. {row.crop} - {round(row.confidence,2)}%\n"

    return jsonify({
        "recommended_crop": crop,
        "formatted_output": formatted_output.strip()
    })


# FERTILIZER RECOMMENDATION

@app.route("/predict_fertilizer", methods=["POST"])
def predict_fertilizer():
    data = request.get_json()
    crop = data["crop"].lower()
    N = float(data["N"]); P = float(data["P"]); K = float(data["K"])

    ideal = {
        # Cereals
        "rice": [90, 40, 40],
        "wheat": [120, 60, 40],
        "maize": [120, 60, 40],
        "sorghum": [100, 50, 40],
        "barley": [80, 40, 40],

        # Pulses
        "chickpea": [20, 40, 20],
        "pigeonpea": [20, 50, 20],
        "green gram": [20, 40, 20],
        "black gram": [20, 40, 20],
        "lentil": [20, 40, 20],

        # Oilseeds
        "groundnut": [25, 50, 75],
        "mustard": [80, 40, 40],
        "sunflower": [60, 60, 40],
        "soybean": [30, 60, 40],
        "sesame": [40, 20, 20],

        # Commercial crops
        "cotton": [150, 75, 75],
        "sugarcane": [250, 115, 115],
        "jute": [60, 30, 30],
        "tobacco": [90, 60, 60],

        # Vegetables
        "tomato": [100, 60, 50],
        "potato": [150, 60, 120],
        "onion": [100, 50, 50],
        "brinjal": [100, 60, 50],
        "cabbage": [120, 60, 60],
        "cauliflower": [120, 60, 60],
        "chilli": [100, 50, 50],
        "okra": [80, 40, 40],
        "carrot": [60, 40, 40],

        # Fruits
        "banana": [200, 60, 200],
        "mango": [100, 50, 100],
        "grapes": [120, 60, 120],
        "orange": [120, 60, 120],
        "apple": [70, 35, 70]
    }

    fert = {
        "NLow": "Ammonium Sulphate",
        "NHigh": "Urea",
        "PLow": "DAP (Diammonium Phosphate)",
        "PHigh": "Single Super Phosphate",
        "KLow": "Sulphate of Potash",
        "KHigh": "Muriate of Potash"
    }

    if crop not in ideal:
        return jsonify({"error": "Sorry, crop not found in fertilizer database."})

    ideal_N, ideal_P, ideal_K = ideal[crop]
    msg = []

    if N < ideal_N:
        msg.append(f"Nitrogen is LOW. Use {fert['NLow']} to improve growth.")
    elif N > ideal_N:
        msg.append(f"Nitrogen is HIGH. Reduce use of {fert['NHigh']}.")
    else:
        msg.append("Nitrogen level is optimal.")

    if P < ideal_P:
        msg.append(f"Phosphorus is LOW. Apply {fert['PLow']} for better roots.")
    elif P > ideal_P:
        msg.append(f"Phosphorus is HIGH. Reduce use of {fert['PHigh']}.")
    else:
        msg.append("Phosphorus level is optimal.")

    if K < ideal_K:
        msg.append(f"Potassium is LOW. Use {fert['KLow']} for strong stems.")
    elif K > ideal_K:
        msg.append(f"Potassium is HIGH. Avoid excess {fert['KHigh']}.")
    else:
        msg.append("Potassium level is optimal.")

    if N == ideal_N and P == ideal_P and K == ideal_K:
        msg = ["Your soil NPK levels are perfect for this crop!"]

    formatted_output = f"""
Crop: {crop.title()}

Your NPK Levels:
N = {N}, P = {P}, K = {K}

Ideal NPK Levels:
N = {ideal_N}, P = {ideal_P}, K = {ideal_K}

Recommendations:
""" + "\n".join(f"- {m}" for m in msg)

    return jsonify({
        "crop": crop,
        "formatted_output": formatted_output.strip()
    })


# MARKET PRICE PREDICTION (Detailed Output for Flutter)

@app.route("/predict_market", methods=["POST"])
def predict_market():
    data = request.get_json()
    state, dist, comm = data["state"], data["district"], data["commodity"]
    weight = float(data.get("weight", 1))
    cost = float(data.get("cost", 0))

    df = pd.read_csv(r"D:\FINAL PROJECT\DATA\price data set\Cleaned_Sorted_Agriculture_Data.csv")
    for c in ["STATE", "District Name", "Commodity", "Variety", "Market Name"]:
        df[c] = label[c].transform(df[c])

    s = label["STATE"].transform([state])[0]
    d = label["District Name"].transform([dist])[0]
    c = label["Commodity"].transform([comm])[0]
    f = df[(df["District Name"] == d) & (df["Commodity"] == c)]
    if f.empty:
        return jsonify({"error": "No data found for this combination."})

    v = f["Variety"].mode()[0]
    m = f["Market Name"].mode()[0]
    day = datetime.datetime.today().toordinal()
    X = pd.DataFrame([[s, d, m, c, v, day]],
                     columns=["STATE", "District Name", "Market Name", "Commodity", "Variety", "Price_Date_Ordinal"])
    price = price_model.predict(X)[0]
    income = price * weight
    profit = (price - cost) * weight

    unique = df[df["STATE"] == s][["District Name", "Market Name"]].drop_duplicates()
    results = []
    for _, row in unique.iterrows():
        di, mk = row["District Name"], row["Market Name"]
        sub = df[(df["District Name"] == di) & (df["Commodity"] == c)]
        if sub.empty:
            continue
        v2 = sub["Variety"].mode()[0]
        X2 = pd.DataFrame([[s, di, mk, c, v2, day]], columns=X.columns)
        pred_price = price_model.predict(X2)[0]
        dist_name = label["District Name"].inverse_transform([di])[0]
        market_name = label["Market Name"].inverse_transform([mk])[0]
        results.append((dist_name, market_name, pred_price))

    top3 = sorted(results, key=lambda x: x[2], reverse=True)[:3]
    best = top3[0]

    # === Pretty Text Output for Flutter ===
    formatted_output = f"""
Your Local Market:
Predicted Modal Price for {comm} in {dist}: ₹{round(price,2)} per quintal
Total Estimated Value for {weight} quintals: ₹{round(income,2)}

Top 3 Market Recommendations in {state}
"""
    for i, (dname, mname, p) in enumerate(top3, 1):
        total = round(p * weight, 2)
        up = round(p - price, 2)
        formatted_output += f"{i}. {mname}, {dname}: ₹{round(p,2)} per quintal → ₹{total} total (↑ ₹{up}/qtl)\n"

    formatted_output += f"""
Best Option: {best[1]}, {best[0]}
Max Estimated Income: ₹{round(best[2]*weight,2)} for {weight} quintals
"""

    return jsonify({
        "predicted_price": round(float(price), 2),
        "formatted_output": formatted_output.strip()
    })


@app.route("/")
def home():
    return " FarmAssist Flask Server Running"

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
