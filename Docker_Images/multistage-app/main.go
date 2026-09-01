package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

const message = "Hello World from Docker multi-stage build"

const page = `<!doctype html>
<html>
  <head><title>Docker Multi-Stage Build</title></head>
  <body style="font-family:sans-serif;text-align:center;padding-top:60px">
    <h1>Hello World from Docker multi-stage build</h1>
    <p>Compiled in a Go builder stage, served from a minimal Alpine runtime stage.</p>
  </body>
</html>`

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Plain-text endpoint, handy for curl based verification
	http.HandleFunc("/text", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, message)
	})

	// HTML page shown in the browser
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprint(w, page)
	})

	log.Printf("multi-stage app listening on port %s", port)
	log.Fatal(http.ListenAndServe("0.0.0.0:"+port, nil))
}
