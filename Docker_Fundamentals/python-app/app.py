from flask import Flask

app = Flask(__name__)


@app.route("/")
def hello():
    return """<!doctype html>
<html>
  <head><title>Python Hello World</title></head>
  <body style="font-family:sans-serif;text-align:center;padding-top:60px">
    <h1>Hello World from Python</h1>
    <p>Served by a Flask application running inside Docker.</p>
  </body>
</html>"""


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
