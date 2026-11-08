# ==============================================================
#                  AI MASTER TRADER
#       Consolidated Multi-Market Paper Trading System
#                  Version 1.0
# ==============================================================
#
# IMPORTANT:
# - PAPER TRADING ONLY
# - LIVE BROKER ORDERS DISABLED
# - Technical-indicator scoring, NOT a guaranteed AI predictor
# - Yahoo Finance data may be delayed or incomplete
#
# ==============================================================

# -------------------- INSTALL DEPENDENCIES --------------------

import sys
import subprocess

subprocess.check_call([
    sys.executable, "-m", "pip", "install", "-q",
    "yfinance", "pandas", "numpy", "requests"
])

# -------------------- IMPORTS --------------------

import os
import json
import time
import math
import requests
import yfinance as yf
import pandas as pd
import numpy as np

from datetime import datetime, date, time as clock_time
from zoneinfo import ZoneInfo
from getpass import getpass

# -------------------- GOOGLE DRIVE --------------------

try:
    from google.colab import drive
    drive.mount("/content/drive")
    PROJECT_DIR = "/content/drive/MyDrive/AI_Master_Trader"
except ImportError:
    PROJECT_DIR = os.path.join(
        os.path.expanduser("~"),
        "AI_Master_Trader"
    )

os.makedirs(PROJECT_DIR, exist_ok=True)

# -------------------- CONFIGURATION --------------------

APP_NAME = "AI MASTER TRADER"
TIMEZONE = ZoneInfo("Asia/Kolkata")

STARTING_BALANCE = 100000

RISK_PER_TRADE = 0.005
DAILY_LOSS_LIMIT = 0.02

MAX_OPEN_POSITIONS = 5
MAX_EXPOSURE = 0.80

SCAN_INTERVAL = 15 * 60
MAX_DATA_AGE_MINUTES = 45

INTRADAY_MODE = True
ALLOW_OVERNIGHT = False

LAST_ENTRY_TIME = clock_time(14, 45)
SQUARE_OFF_TIME = clock_time(15, 15)

PAPER_MODE = True
LIVE_BROKER_ORDERS_ENABLED = False

# Change to True only when you deliberately want
# the program to keep scanning in this session.
RUN_AUTOMATION = False

PORTFOLIO_FILE = os.path.join(
    PROJECT_DIR, "portfolio.json"
)

TRADE_FILE = os.path.join(
    PROJECT_DIR, "trade_history.csv"
)

SCAN_FILE = os.path.join(
    PROJECT_DIR, "scan_history.csv"
)

LIVE_SCAN_FILE = os.path.join(
    PROJECT_DIR, "scan_history_live.csv"
)

# -------------------- 19-MARKET WATCHLIST --------------------

MARKETS = {
    "Reliance": "RELIANCE.NS",
    "TCS": "TCS.NS",

    "NIFTY 50": "^NSEI",
    "SENSEX": "^BSESN",
    "BANK NIFTY": "^NSEBANK",

    "Apple": "AAPL",
    "Tesla": "TSLA",
    "Nvidia": "NVDA",

    "Bitcoin": "BTC-USD",
    "Ethereum": "ETH-USD",

    "EUR/USD": "EURUSD=X",
    "GBP/USD": "GBPUSD=X",

    "Gold": "GC=F",
    "Silver": "SI=F",
    "Crude Oil": "CL=F",
    "Natural Gas": "NG=F",

    "S&P 500": "^GSPC",
    "NASDAQ": "^IXIC",
    "US Bonds ETF": "TLT"
}

# Only these instruments can receive paper trades.
EXECUTABLE_MARKETS = {
    "Reliance": "RELIANCE.NS",
    "TCS": "TCS.NS"
}

# -------------------- TELEGRAM CONFIGURATION --------------------

BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")

if not BOT_TOKEN:
    BOT_TOKEN = getpass(
        "Telegram bot token (press Enter to skip): "
    ).strip()

if not CHAT_ID and BOT_TOKEN:
    CHAT_ID = input(
        "Telegram chat ID: "
    ).strip()


def send_telegram(message):

    if not BOT_TOKEN or not CHAT_ID:
        return False

    try:
        url = (
            "https://api.telegram.org/bot"
            + BOT_TOKEN
            + "/sendMessage"
        )

        response = requests.post(
            url,
            data={
                "chat_id": CHAT_ID,
                "text": message
            },
            timeout=15
        )

        return response.ok

    except Exception as error:
        print("Telegram notification error:", error)
        return False


# -------------------- PORTFOLIO DATABASE --------------------

def load_portfolio():

    if os.path.exists(PORTFOLIO_FILE):

        try:
            with open(PORTFOLIO_FILE, "r") as file:
                data = json.load(file)

            if "positions" not in data:
                raise ValueError("Invalid portfolio structure")

            return data

        except Exception as error:
            print("Portfolio loading error:", error)
            raise

    return {
        "starting_balance": STARTING_BALANCE,
        "cash": STARTING_BALANCE,
        "positions": {},
        "realized_pnl": 0.0,
        "daily_date": str(date.today()),
        "daily_realized_pnl": 0.0,
        "daily_start_equity": STARTING_BALANCE,
        "last_processed_bar": {}
    }


portfolio = load_portfolio()


def save_portfolio():

    temporary_file = PORTFOLIO_FILE + ".tmp"

    with open(temporary_file, "w") as file:
        json.dump(portfolio, file, indent=4)

    os.replace(temporary_file, PORTFOLIO_FILE)


# -------------------- TRADE HISTORY --------------------

TRADE_COLUMNS = [
    "Timestamp",
    "Market",
    "Symbol",
    "Action",
    "Quantity",
    "Price",
    "Value",
    "Reason",
    "Realized_PnL"
]


def record_trade(
    action,
    market,
    quantity,
    price,
    pnl,
    reason
):

    record = {
        "Timestamp": datetime.now(TIMEZONE).isoformat(),
        "Market": market,
        "Symbol": EXECUTABLE_MARKETS[market],
        "Action": action,
        "Quantity": quantity,
        "Price": round(float(price), 4),
        "Value": round(quantity * price, 2),
        "Reason": reason,
        "Realized_PnL": round(float(pnl), 2)
    }

    pd.DataFrame([record]).to_csv(
        TRADE_FILE,
        mode="a",
        header=(
            not os.path.exists(TRADE_FILE)
            or os.path.getsize(TRADE_FILE) == 0
        ),
        index=False
    )


if not os.path.exists(TRADE_FILE):
    pd.DataFrame(columns=TRADE_COLUMNS).to_csv(
        TRADE_FILE, index=False
    )


# -------------------- MARKET SESSION --------------------

def current_time():
    return datetime.now(TIMEZONE)


def nse_session_open():

    now = current_time()

    return (
        now.weekday() < 5
        and clock_time(9, 15)
        <= now.time()
        <= clock_time(15, 30)
    )


def entries_allowed():

    now = current_time()

    return (
        nse_session_open()
        and now.time() < LAST_ENTRY_TIME
    )


# NOTE:
# This weekday/time check does not include the official
# NSE holiday calendar or special trading sessions.
# Verify exchange holidays separately.


# -------------------- TECHNICAL ANALYSIS --------------------

def analyse_market(name, symbol):

    try:

        df = yf.Ticker(symbol).history(
            period="60d",
            interval="15m",
            auto_adjust=True
        )

        if df.empty or len(df) < 60:
            return None

        df = df.dropna(subset=["Close"])

        close = df["Close"]
        high = df["High"]
        low = df["Low"]

        # Exponential moving averages

        ema20 = close.ewm(
            span=20,
            adjust=False
        ).mean()

        ema50 = close.ewm(
            span=50,
            adjust=False
        ).mean()

        # RSI

        delta = close.diff()

        gain = delta.clip(lower=0).rolling(14).mean()
        loss = (-delta.clip(upper=0)).rolling(14).mean()

        rs = gain / loss.replace(0, np.nan)

        rsi = 100 - (100 / (1 + rs))

        # MACD

        macd = (
            close.ewm(span=12, adjust=False).mean()
            -
            close.ewm(span=26, adjust=False).mean()
        )

        macd_signal = macd.ewm(
            span=9,
            adjust=False
        ).mean()

        # Average True Range

        previous_close = close.shift(1)

        tr = pd.concat(
            [
                high - low,
                (high - previous_close).abs(),
                (low - previous_close).abs()
            ],
            axis=1
        ).max(axis=1)

        atr = tr.rolling(14).mean()

        price = float(close.iloc[-1])
        current_rsi = float(rsi.iloc[-1])
        current_atr = float(atr.iloc[-1])

        if not np.isfinite(current_rsi):
            return None

        if not np.isfinite(current_atr):
            return None

        score = 0

        # Trend scoring

        if ema20.iloc[-1] > ema50.iloc[-1]:
            score += 2
        else:
            score -= 2

        # Price momentum

        if price > ema20.iloc[-1]:
            score += 1
        else:
            score -= 1

        # MACD confirmation

        if macd.iloc[-1] > macd_signal.iloc[-1]:
            score += 1
        else:
            score -= 1

        # RSI confirmation

        if 50 <= current_rsi <= 68:
            score += 1

        elif 32 <= current_rsi < 50:
            score -= 1

        # Volume confirmation

        volume_ratio = np.nan

        if "Volume" in df.columns:

            avg_volume = df["Volume"].rolling(20).mean()

            if (
                pd.notna(avg_volume.iloc[-1])
                and avg_volume.iloc[-1] > 0
            ):

                volume_ratio = (
                    float(df["Volume"].iloc[-1])
                    /
                    float(avg_volume.iloc[-1])
                )

                if volume_ratio >= 1.2:

                    if price > ema20.iloc[-1]:
                        score += 1
                    else:
                        score -= 1

        # Decision

        if score >= 4:
            decision = "BUY"

        elif score <= -4:
            decision = "SELL"

        else:
            decision = "HOLD"

        # Data freshness

        bar_time = pd.Timestamp(df.index[-1])

        if bar_time.tzinfo is None:
            bar_time = bar_time.tz_localize("UTC")

        bar_utc = bar_time.tz_convert("UTC")

        age_minutes = (
            pd.Timestamp.now(tz="UTC") - bar_utc
        ).total_seconds() / 60

        return {
            "Market": name,
            "Symbol": symbol,
            "Price": price,
            "Score": score,
            "Decision": decision,
            "RSI": current_rsi,
            "ATR": current_atr,
            "High": float(high.iloc[-1]),
            "Low": float(low.iloc[-1]),
            "Bar": str(bar_time),
            "Age_Minutes": age_minutes,
            "Volume_Ratio": volume_ratio
        }

    except Exception as error:

        print(
            f"Market analysis failed for {name}: "
            f"{str(error)[:150]}"
        )

        return None


# -------------------- PORTFOLIO CALCULATIONS --------------------

def get_equity(prices):

    market_value = 0.0

    for market, position in portfolio["positions"].items():

        price = prices.get(
            market,
            position["entry_price"]
        )

        market_value += (
            position["quantity"] * price
        )

    return float(portfolio["cash"]) + market_value


def get_unrealized_pnl(prices):

    result = 0.0

    for market, position in portfolio["positions"].items():

        price = prices.get(
            market,
            position["entry_price"]
        )

        result += (
            price - position["entry_price"]
        ) * position["quantity"]

    return result


# -------------------- POSITION CLOSING --------------------

def close_position(market, price, reason):

    if market not in portfolio["positions"]:
        return None

    position = portfolio["positions"][market]

    quantity = position["quantity"]
    entry_price = position["entry_price"]

    pnl = (
        price - entry_price
    ) * quantity

    portfolio["cash"] += quantity * price

    portfolio["realized_pnl"] += pnl

    portfolio["daily_realized_pnl"] += pnl

    record_trade(
        "SELL",
        market,
        quantity,
        price,
        pnl,
        reason
    )

    del portfolio["positions"][market]

    event = (
        f"VIRTUAL EXIT: {market}\n"
        f"Quantity: {quantity}\n"
        f"Exit price: {price:.2f}\n"
        f"Profit/Loss: ₹{pnl:.2f}\n"
        f"Reason: {reason}"
    )

    print(event)

    send_telegram(
        "AI MASTER TRADER\n\n" + event
    )

    return pnl


# -------------------- POSITION MANAGEMENT --------------------

def manage_positions(results, prices, fresh):

    events = []

    now = current_time()

    session = nse_session_open()

    square_off_due = (
        INTRADAY_MODE
        and now.time() >= SQUARE_OFF_TIME
    )

    if not session and not square_off_due:
        return

    for market in list(portfolio["positions"].keys()):

        if market not in prices:
            continue

        if not fresh.get(market, False):
            continue

        row = next(
            (
                item for item in results
                if item["Market"] == market
            ),
            None
        )

        if row is None:
            continue

        position = portfolio["positions"][market]

        last_bar = portfolio["last_processed_bar"].get(
            market
        )

        if last_bar == row["Bar"] and not square_off_due:
            continue

        portfolio["last_processed_bar"][market] = row["Bar"]

        exit_price = None
        reason = None

        if square_off_due:

            exit_price = row["Price"]
            reason = "Intraday square-off"

        elif row["Low"] <= position["stop_loss"]:

            exit_price = position["stop_loss"]
            reason = "Stop-loss triggered"

        elif row["High"] >= position["target"]:

            exit_price = position["target"]
            reason = "Target reached"

        elif row["Decision"] == "SELL":

            exit_price = row["Price"]
            reason = "SELL signal"

        # Trailing stop: update only after checking
        # the current candle's existing stop.

        if exit_price is None and not square_off_due:

            new_trailing_stop = (
                row["Price"] - 1.5 * row["ATR"]
            )

            if new_trailing_stop > position["stop_loss"]:

                position["stop_loss"] = new_trailing_stop

        if exit_price is not None:

            close_position(
                market,
                exit_price,
                reason
            )

            events.append(market)

    return events


# -------------------- PAPER BUY EXECUTION --------------------

def open_position(market, row, prices):

    if not PAPER_MODE:
        print("Safety lock: paper mode must remain enabled.")
        return False

    if LIVE_BROKER_ORDERS_ENABLED:
        print("Live broker execution is not implemented.")
        return False

    if market not in EXECUTABLE_MARKETS:
        return False

    if market in portfolio["positions"]:
        return False

    if len(portfolio["positions"]) >= MAX_OPEN_POSITIONS:
        return False

    price = float(row["Price"])
    atr = float(row["ATR"])

    stop = price - (1.5 * atr)
    target = price + (3.0 * atr)

    risk_per_share = price - stop

    if price <= 0 or risk_per_share <= 0:
        return False

    equity = get_equity(prices)

    risk_budget = equity * RISK_PER_TRADE

    quantity_by_risk = math.floor(
        risk_budget / risk_per_share
    )

    quantity_by_cash = math.floor(
        portfolio["cash"] / price
    )

    maximum_exposure = (
        portfolio["starting_balance"] * MAX_EXPOSURE
    )

    invested = sum(
        p["quantity"] * p["entry_price"]
        for p in portfolio["positions"].values()
    )

    available_exposure = max(
        0,
        maximum_exposure - invested
    )

    quantity_by_exposure = math.floor(
        available_exposure / price
    )

    quantity = min(
        quantity_by_risk,
        quantity_by_cash,
        quantity_by_exposure
    )

    if quantity < 1:
        print("Insufficient cash or risk capacity:", market)
        return False

    cost = quantity * price

    portfolio["cash"] -= cost

    portfolio["positions"][market] = {
        "symbol": EXECUTABLE_MARKETS[market],
        "quantity": quantity,
        "entry_price": price,
        "stop_loss": stop,
        "target": target,
        "entry_time": current_time().isoformat()
    }

    portfolio["last_processed_bar"][market] = row["Bar"]

    record_trade(
        "BUY",
        market,
        quantity,
        price,
        0,
        "Balanced 15-minute BUY signal"
    )

    event = (
        f"VIRTUAL BUY: {market}\n"
        f"Quantity: {quantity}\n"
        f"Entry: ₹{price:.2f}\n"
        f"Stop-loss: ₹{stop:.2f}\n"
        f"Target: ₹{target:.2f}\n"
        f"Risk budget: ₹{risk_budget:.2f}"
    )

    print(event)

    send_telegram(
        "AI MASTER TRADER\n\n" + event
    )

    return True


# -------------------- MAIN SCANNER --------------------

def master_scan():

    print("\n" + "=" * 60)
    print(APP_NAME)
    print("Time:", current_time().strftime("%d-%m-%Y %H:%M:%S"))
    print("Mode: PAPER TRADING")
    print("=" * 60)

    results = []

    # Scan all 19 markets

    for name, symbol in MARKETS.items():

        result = analyse_market(name, symbol)

        if result:

            results.append(result)

            print(
                f"{name:15} | "
                f"{result['Decision']:5} | "
                f"Score: {result['Score']:3} | "
                f"Price: {result['Price']:.4f}"
            )

        else:

            print(f"{name:15} | DATA UNAVAILABLE")

    if not results:

        print("No usable market data.")
        return

    df = pd.DataFrame(results)

    df["Scan_Time"] = current_time().isoformat()

    # Save scan history

    df.to_csv(
        SCAN_FILE,
        mode="a",
        header=(
            not os.path.exists(SCAN_FILE)
            or os.path.getsize(SCAN_FILE) == 0
        ),
        index=False
    )

    df.to_csv(
        LIVE_SCAN_FILE,
        mode="a",
        header=(
            not os.path.exists(LIVE_SCAN_FILE)
            or os.path.getsize(LIVE_SCAN_FILE) == 0
        ),
        index=False
    )

    # Prices for executable instruments

    prices = {}
    fresh = {}

    for market in EXECUTABLE_MARKETS:

        row = next(
            (
                item for item in results
                if item["Market"] == market
            ),
            None
        )

        if row:

            prices[market] = row["Price"]

            fresh[market] = (
                row["Age_Minutes"] <= MAX_DATA_AGE_MINUTES
            )

    # Daily reset

    today = str(date.today())

    if portfolio["daily_date"] != today:

        portfolio["daily_date"] = today

        portfolio["daily_realized_pnl"] = 0.0

        portfolio["daily_start_equity"] = get_equity(
            prices
        )

    if portfolio["daily_start_equity"] <= 0:

        portfolio["daily_start_equity"] = get_equity(
            prices
        )

    # Manage existing positions

    manage_positions(
        results,
        prices,
        fresh
    )

    # Daily loss protection includes unrealized losses.

    equity = get_equity(prices)

    daily_drawdown = (
        portfolio["daily_start_equity"] - equity
    )

    daily_loss_limit = (
        portfolio["daily_start_equity"]
        * DAILY_LOSS_LIMIT
    )

    daily_loss_hit = (
        daily_drawdown >= daily_loss_limit
    )

    if daily_loss_hit:

        print("DAILY LOSS LIMIT REACHED.")
        print("New BUY entries are blocked.")

    # New entries

    if entries_allowed() and not daily_loss_hit:

        for market in EXECUTABLE_MARKETS:

            row = next(
                (
                    item for item in results
                    if item["Market"] == market
                ),
                None
            )

            if row is None:
                continue

            if not fresh.get(market, False):
                print("Stale data: entry blocked:", market)
                continue

            if row["Decision"] != "BUY":
                continue

            if row["Score"] < 4:
                continue

            if market in portfolio["positions"]:
                continue

            open_position(
                market,
                row,
                prices
            )

    elif not entries_allowed():

        print("Outside permitted NSE entry window.")

    # Account summary

    equity = get_equity(prices)

    unrealized = get_unrealized_pnl(prices)

    print("\n" + "=" * 45)
    print("PAPER ACCOUNT SUMMARY")
    print("=" * 45)

    print(
        f"Starting balance: ₹"
        f"{portfolio['starting_balance']:,.2f}"
    )

    print(
        f"Available cash: ₹"
        f"{portfolio['cash']:,.2f}"
    )

    print(
        f"Open positions: "
        f"{len(portfolio['positions'])}"
    )

    print(
        f"Unrealized P/L: ₹{unrealized:,.2f}"
    )

    print(
        f"Realized P/L: ₹"
        f"{portfolio['realized_pnl']:,.2f}"
    )

    print(
        f"Virtual equity: ₹{equity:,.2f}"
    )

    print(
        f"Daily drawdown: ₹{daily_drawdown:,.2f}"
    )

    print("Paper mode: ENABLED")
    print("Live broker orders: DISABLED")

    save_portfolio()


# -------------------- STARTUP CHECK --------------------

print("\n" + "=" * 60)
print("AI MASTER TRADER — SYSTEM PREFLIGHT")
print("=" * 60)

print("Markets monitored:", len(MARKETS))
print("Paper execution markets:", list(EXECUTABLE_MARKETS))
print("Starting capital: ₹", STARTING_BALANCE)
print("Risk per trade:", RISK_PER_TRADE * 100, "%")
print("Daily loss limit:", DAILY_LOSS_LIMIT * 100, "%")
print("Maximum positions:", MAX_OPEN_POSITIONS)
print("Scan interval:", SCAN_INTERVAL // 60, "minutes")

print("Paper mode:", PAPER_MODE)
print("Live broker orders:", LIVE_BROKER_ORDERS_ENABLED)
print("Automation:", RUN_AUTOMATION)

print("Portfolio file:", PORTFOLIO_FILE)
print("Trade history:", TRADE_FILE)

if not PAPER_MODE or LIVE_BROKER_ORDERS_ENABLED:
    raise RuntimeError(
        "Safety configuration invalid. Execution stopped."
    )

save_portfolio()

# -------------------- RUN ENGINE --------------------

if RUN_AUTOMATION:

    print("\nAUTOMATION STARTED")
    print("Stop the running cell to stop automation.")

    try:

        while True:

            started = time.monotonic()

            try:
                master_scan()

            except Exception as error:

                print("Scan error:", error)

                send_telegram(
                    "AI MASTER TRADER ERROR\n"
                    + str(error)[:500]
                )

            elapsed = time.monotonic() - started

            wait = max(
                0,
                SCAN_INTERVAL - elapsed
            )

            print(
                f"\nNext scan in "
                f"{wait / 60:.1f} minutes."
            )

            time.sleep(wait)

    except KeyboardInterrupt:

        print("\nAutomation stopped.")

        save_portfolio()

else:

    print("\nAUTOMATION IS STOPPED BY DEFAULT.")
    print("Running one manual paper scan.")

    master_scan()

print("\nAI MASTER TRADER SESSION COMPLETE.")
print("PAPER TRADING ONLY — NO REAL ORDERS.")