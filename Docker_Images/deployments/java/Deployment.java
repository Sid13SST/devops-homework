import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

public class Deployment {

    public static void main(String[] args) throws IOException {
        int port = 4003;
        String host = InetAddress.getLocalHost().getHostName();
        HttpServer server = HttpServer.create(new InetSocketAddress("0.0.0.0", port), 0);

        server.createContext("/health", exchange -> {
            String json = "{\"status\":\"up\",\"runtime\":\"java\",\"host\":\"" + host + "\"}";
            respond(exchange, json, "application/json");
        });

        server.createContext("/", exchange -> {
            String html = "<h1>Java deployment</h1><p>Container: " + host
                    + "</p><p><a href=\"/health\">/health</a></p>";
            respond(exchange, html, "text/html; charset=utf-8");
        });

        server.setExecutor(null);
        server.start();
        System.out.println("java deployment on " + port);
    }

    private static void respond(com.sun.net.httpserver.HttpExchange exchange,
                                String body, String contentType) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("Content-Type", contentType);
        exchange.sendResponseHeaders(200, bytes.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(bytes);
        }
    }
}
