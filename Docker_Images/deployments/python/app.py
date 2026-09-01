import socket

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/health")
def health():
    return jsonify(status="up", runtime="python", host=socket.gethostname())


@app.route("/")
def index():
    return (
        f"<h1>Python deployment</h1>"
        f"<p>Container: {socket.gethostname()}</p>"
        f'<p><a href="/health">/health</a></p>'
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=4002)
