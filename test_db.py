import urllib.request
import json

url = "https://qqvwvuwwcfihzoiwjesa.supabase.co/rest/v1/exercise_sets?select=*"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFxdnd2dXd3Y2ZpaHpvaXdqZXNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3MDI1NDksImV4cCI6MjA5MzI3ODU0OX0.lw_y_bciXyk4VyCX4uuM8FSWUnmMbup1C_t_SsK2WKI"

req = urllib.request.Request(url, headers={
    "apikey": key,
    "Authorization": f"Bearer {key}"
})

try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        print(f"Total records: {len(data)}")
        for row in data:
            print(row)
except Exception as e:
    print(e)
