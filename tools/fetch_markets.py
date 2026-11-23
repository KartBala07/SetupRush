# Rebuilds SetupRush/Resources/markets.json from Coinbase Exchange public candles.
import json, urllib.request, time, datetime, sys

PRODUCTS = ["BTC-USD","ETH-USD","SOL-USD","DOGE-USD","LINK-USD","AVAX-USD","XRP-USD","SUI-USD"]
GRAN = 900
DAYS = 11

def get(url):
    last=None
    for i in range(5):
        try:
            req=urllib.request.Request(url, headers={"User-Agent":"SetupRushClone/1.0","Accept":"application/json"})
            with urllib.request.urlopen(req, timeout=25) as r:
                return json.load(r)
        except Exception as e:
            last=e; time.sleep(1.2*(i+1))
    print("FAIL", url, last, file=sys.stderr); return None

out={}
now=int(time.time())
for p in PRODUCTS:
    rows={}
    end=now
    for page in range(6):
        start=end-256000
        url=f"https://api.exchange.coinbase.com/products/{p}/candles?granularity={GRAN}&start={datetime.datetime.utcfromtimestamp(start).isoformat()}Z&end={datetime.datetime.utcfromtimestamp(end).isoformat()}Z"
        d=get(url)
        if not d: break
        for r in d: rows[int(r[0])]=r
        end=start
        time.sleep(0.35)
    cs=[[t,rows[t][3],rows[t][2],rows[t][1],rows[t][4],rows[t][5]] for t in sorted(rows)]  # t, o,h,l,c,v  (coinbase: time,low,high,open,close,volume)
    out[p]={"candles":cs}
    print(p, len(cs))
json.dump({"granularity":GRAN,"generated":now,"markets":out}, open(__import__("os").path.join(__import__("os").path.dirname(__file__), "..", "SetupRush", "Resources", "markets.json"),"w"), separators=(",",":"))
