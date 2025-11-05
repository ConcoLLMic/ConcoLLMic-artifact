// Comprehensive test server for libsoup
// Combines functionality from multiple examples and adds cookie support,
// authentication, and WebSocket support

#include <libsoup/soup.h>
#include <glib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>

// Debug settings
static gboolean verbose_mode = TRUE;
static gboolean quiet_mode = FALSE;

// Server configuration
static int port = 8080;
static const char *tls_cert_file = NULL;
static const char *tls_key_file = NULL;
static char *docroot = NULL;
static gboolean auth_enabled = FALSE;
static gboolean websocket_enabled = TRUE;

// Authentication domains
static SoupAuthDomain *basic_auth_domain = NULL;
static SoupAuthDomain *digest_auth_domain = NULL;

// Mime type mapping
static GHashTable *mime_types = NULL;

// WebSocket connections
static GSList *websocket_connections = NULL;
static GMutex websocket_mutex;

// Function prototypes
void sig_handler(int signo);

void sig_handler(int signo)
{
  if (signo == SIGUSR1)
    exit(0);
}

// Helper function to print debug info
static void 
debug_print(const char *format, ...) {
    if (quiet_mode)
        return;
    
    va_list args;
    va_start(args, format);
    g_print("[DEBUG] ");
    
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wformat-nonliteral"
    vprintf(format, args);
#pragma GCC diagnostic pop
    g_print("\n");
    va_end(args);
}

// Print request headers
static void
print_request_headers(SoupServerMessage *msg) {
    if (quiet_mode)
        return;
    
    SoupMessageHeaders *headers = soup_server_message_get_request_headers(msg);
    SoupMessageHeadersIter iter;
    const char *name, *value;
    
    debug_print("Request headers:");
    soup_message_headers_iter_init(&iter, headers);
    while (soup_message_headers_iter_next(&iter, &name, &value))
        debug_print("  %s: %s", name, value);
}

// Print response headers
static void
print_response_headers(SoupServerMessage *msg) {
    if (quiet_mode)
        return;
    
    SoupMessageHeaders *headers = soup_server_message_get_response_headers(msg);
    SoupMessageHeadersIter iter;
    const char *name, *value;
    
    debug_print("Response headers:");
    soup_message_headers_iter_init(&iter, headers);
    while (soup_message_headers_iter_next(&iter, &name, &value))
        debug_print("  %s: %s", name, value);
}

// Parse and display cookies from request
static void
handle_cookies(SoupServerMessage *msg) {
    SoupMessageHeaders *headers = soup_server_message_get_request_headers(msg);
    const char *cookie_header = soup_message_headers_get_one(headers, "Cookie");
    
    if (cookie_header) {
        debug_print("Received cookie header: %s", cookie_header);
        
        // Parse cookies from the header
        char **cookies = g_strsplit(cookie_header, ";", -1);
        for (int i = 0; cookies[i]; i++) {
            char *cookie_str = g_strstrip(cookies[i]);
            GUri *origin = soup_server_message_get_uri(msg);
            
            // This call triggers soup_cookie_parse
            debug_print("Parsing cookie: %s", cookie_str);
            SoupCookie *cookie = soup_cookie_parse(cookie_str, origin);
            
            if (cookie) {
                debug_print("Parsed cookie: name='%s', value='%s', domain='%s', path='%s'",
                           soup_cookie_get_name(cookie),
                           soup_cookie_get_value(cookie),
                           soup_cookie_get_domain(cookie),
                           soup_cookie_get_path(cookie));
                
                // Free the cookie
                soup_cookie_free(cookie);
            } else {
                debug_print("Failed to parse cookie: %s", cookie_str);
            }
        }
        
        g_strfreev(cookies);
    } else {
        debug_print("No cookies in request");
    }
}

// Set a test cookie in response
static void
set_test_cookie(SoupServerMessage *msg) {
    GUri *uri = soup_server_message_get_uri(msg);
    const char *host = g_uri_get_host(uri);
    
    // Create a test cookie
    SoupCookie *cookie = soup_cookie_new("TestCookie", "TestValue", host, "/", 3600);
    char *cookie_str = soup_cookie_to_set_cookie_header(cookie);
    
    debug_print("Setting cookie: %s", cookie_str);
    soup_message_headers_append(soup_server_message_get_response_headers(msg),
                               "Set-Cookie", cookie_str);
    
    g_free(cookie_str);
    soup_cookie_free(cookie);
}

// Handle form data processing
static void
handle_form_data(SoupServerMessage *msg) {
    SoupMessageHeaders *headers = soup_server_message_get_request_headers(msg);
    SoupMessageBody *body = soup_server_message_get_request_body(msg);
    
    const char *content_type = soup_message_headers_get_content_type(headers, NULL);
    if (!content_type) {
        debug_print("No content type in form submission");
        return;
    }
    
    debug_print("Processing form with content-type: %s", content_type);
    
    if (g_str_has_prefix(content_type, "multipart/form-data")) {
        // Handle multipart form data
        GBytes *body_bytes = soup_message_body_flatten(body);
        SoupMultipart *multipart = soup_multipart_new_from_message(headers, body_bytes);
        
        if (multipart) {
            debug_print("Successfully parsed multipart form data");
            int count = soup_multipart_get_length(multipart);
            debug_print("Found %d form parts", count);
            
            // Process each part
            for (int i = 0; i < count; i++) {
                SoupMessageHeaders *part_headers;
                GBytes *part_body;
                
                if (soup_multipart_get_part(multipart, i, &part_headers, &part_body)) {
                    const char *disposition = soup_message_headers_get_one(part_headers, "Content-Disposition");
                    if (disposition) {
                        debug_print("Part %d disposition: %s", i, disposition);
                    }
                    
                    gsize size;
                    g_bytes_get_data(part_body, &size);
                    debug_print("Part %d size: %zu bytes", i, size);
                    
                    g_bytes_unref(part_body);
                }
            }
            
            soup_multipart_free(multipart);
        } else {
            debug_print("Failed to parse multipart form data");
        }
        
        g_bytes_unref(body_bytes);
    } else if (g_str_has_prefix(content_type, "application/x-www-form-urlencoded")) {
        // Handle URL-encoded form data
        GBytes *body_bytes = soup_message_body_flatten(body);
        gsize length;
        const char *data = g_bytes_get_data(body_bytes, &length);
        
        debug_print("URL-encoded form data (%zu bytes): %.*s", length, (int)length, data);
        
        // Parse form data
        GHashTable *form_data = soup_form_decode(data);
        if (form_data) {
            debug_print("Parsed form data:");
            GHashTableIter iter;
            gpointer key, value;
            
            g_hash_table_iter_init(&iter, form_data);
            while (g_hash_table_iter_next(&iter, &key, &value)) {
                debug_print("  %s = %s", (char *)key, (char *)value);
            }
            
            g_hash_table_destroy(form_data);
        }
        
        g_bytes_unref(body_bytes);
    }
}

// Initialize mime types
static void
init_mime_types(void) {
    mime_types = g_hash_table_new(g_str_hash, g_str_equal);
    
    // Common MIME types
    g_hash_table_insert(mime_types, ".html", "text/html");
    g_hash_table_insert(mime_types, ".htm", "text/html");
    g_hash_table_insert(mime_types, ".css", "text/css");
    g_hash_table_insert(mime_types, ".js", "application/javascript");
    g_hash_table_insert(mime_types, ".json", "application/json");
    g_hash_table_insert(mime_types, ".xml", "application/xml");
    g_hash_table_insert(mime_types, ".png", "image/png");
    g_hash_table_insert(mime_types, ".jpg", "image/jpeg");
    g_hash_table_insert(mime_types, ".jpeg", "image/jpeg");
    g_hash_table_insert(mime_types, ".gif", "image/gif");
    g_hash_table_insert(mime_types, ".svg", "image/svg+xml");
    g_hash_table_insert(mime_types, ".txt", "text/plain");
    g_hash_table_insert(mime_types, ".pdf", "application/pdf");
    g_hash_table_insert(mime_types, ".zip", "application/zip");
}

// Get mime type for a file
static const char *
get_mime_type(const char *path) {
    const char *mime_type = NULL;
    const char *extension;
    
    extension = strrchr(path, '.');
    if (extension) {
        mime_type = g_hash_table_lookup(mime_types, extension);
    }
    
    return mime_type ? mime_type : "application/octet-stream";
}

// Handle Range requests
static void
handle_range_request(SoupServerMessage *msg, GMappedFile *mapping, const char *content_type, 
                     gsize file_size) {
    SoupMessageHeaders *request_headers = soup_server_message_get_request_headers(msg);
    SoupMessageHeaders *response_headers = soup_server_message_get_response_headers(msg);
    const char *range_header;
    
    range_header = soup_message_headers_get_one(request_headers, "Range");
    if (range_header && g_str_has_prefix(range_header, "bytes=")) {
        gssize start, end;
        char *spec = g_strdup(range_header + 6);
        char **ranges = g_strsplit(spec, ",", -1);
        
        // We only handle a single range for simplicity
        if (ranges && ranges[0] && !ranges[1]) {
            char *range_spec = ranges[0];
            char **range_parts = g_strsplit(range_spec, "-", 2);
            
            if (range_parts && range_parts[0] && range_parts[1]) {
                // Handle "bytes=0-499" (first 500 bytes)
                if (range_parts[0][0] != '\0') {
                    start = atoll(range_parts[0]);
                    if (range_parts[1][0] != '\0')
                        end = MIN(atoll(range_parts[1]), file_size - 1);
                    else
                        end = file_size - 1;
                }
                // Handle "bytes=-500" (last 500 bytes)
                else if (range_parts[1][0] != '\0') {
                    gssize length = atoll(range_parts[1]);
                    start = (length < file_size) ? (file_size - length) : 0;
                    end = file_size - 1;
                } else {
                    start = 0;
                    end = file_size - 1;
                }
                
                // Valid range
                if (start >= 0 && start < file_size && end >= start && end < file_size) {
                    gssize length = end - start + 1;
                    GBytes *buffer;
                    char *content_range;
                    
                    debug_print("Range request: %lld-%lld", (long long)start, (long long)end);
                    
                    // Create a subbuffer with just the requested range
                    buffer = g_bytes_new_with_free_func(
                        g_mapped_file_get_contents(mapping) + start,
                        length,
                        (GDestroyNotify)g_mapped_file_unref,
                        g_mapped_file_ref(mapping));
                    
                    // Set Content-Range header
                    content_range = g_strdup_printf("bytes %lld-%lld/%lld",
                                                  (long long)start,
                                                  (long long)end,
                                                  (long long)file_size);
                    
                    soup_server_message_set_status(msg, SOUP_STATUS_PARTIAL_CONTENT, NULL);
                    soup_message_headers_append(response_headers, "Content-Range", content_range);
                    soup_message_headers_append(response_headers, "Content-Type", content_type);
                    soup_message_body_append_bytes(soup_server_message_get_response_body(msg), buffer);
                    
                    g_free(content_range);
                    g_bytes_unref(buffer);
                    g_strfreev(range_parts);
                    g_strfreev(ranges);
                    g_free(spec);
                    return;
                }
            }
            
            g_strfreev(range_parts);
        }
        
        g_strfreev(ranges);
        g_free(spec);
    }
    
    // If we reached here, either there was no Range header, or we couldn't parse it
    // Set Content-Type header
    soup_message_headers_append(response_headers, "Content-Type", content_type);
    
    // Serve the entire file
    GBytes *buffer = g_bytes_new_with_free_func(g_mapped_file_get_contents(mapping),
                                            g_mapped_file_get_length(mapping),
                                            (GDestroyNotify)g_mapped_file_unref, mapping);
    soup_message_body_append_bytes(soup_server_message_get_response_body(msg), buffer);
    g_bytes_unref(buffer);
}

// File handling for GET/HEAD requests
static void
handle_file_request(SoupServer *server, SoupServerMessage *msg, const char *path) {
    char *file_path;
    struct stat st;
    
    if (docroot)
        file_path = g_strdup_printf("%s%s", docroot, path);
    else
        file_path = g_strdup_printf(".%s", path);
    
    debug_print("Trying to access file: %s", file_path);
    
    if (stat(file_path, &st) == -1) {
        if (errno == EPERM)
            soup_server_message_set_status(msg, SOUP_STATUS_FORBIDDEN, NULL);
        else if (errno == ENOENT)
            soup_server_message_set_status(msg, SOUP_STATUS_NOT_FOUND, NULL);
        else
            soup_server_message_set_status(msg, SOUP_STATUS_INTERNAL_SERVER_ERROR, NULL);
        
        g_free(file_path);
        return;
    }
    
    if (g_file_test(file_path, G_FILE_TEST_IS_DIR)) {
        char *index_path = g_strdup_printf("%s/index.html", file_path);
        
        if (stat(index_path, &st) != -1) {
            g_free(file_path);
            file_path = index_path;
        } else {
            g_free(index_path);
            
            // Return directory listing
            GString *listing = g_string_new("<html><body><h1>Directory Listing</h1><ul>");
            
            GDir *dir = g_dir_open(file_path, 0, NULL);
            if (dir) {
                const char *name;
                while ((name = g_dir_read_name(dir))) {
                    char *item_path = g_strdup_printf("%s/%s", file_path, name);
                    gboolean is_dir = g_file_test(item_path, G_FILE_TEST_IS_DIR);
                    g_free(item_path);
                    
                    g_string_append_printf(listing, "<li><a href=\"%s%s\">%s%s</a></li>",
                                          path[strlen(path) - 1] == '/' ? path : g_strdup_printf("%s/", path),
                                          name, name, is_dir ? "/" : "");
                }
                g_dir_close(dir);
            }
            
            g_string_append(listing, "</ul></body></html>");
            
            soup_server_message_set_status(msg, SOUP_STATUS_OK, NULL);
            soup_server_message_set_response(msg, "text/html", SOUP_MEMORY_TAKE,
                                      g_string_free(listing, FALSE), listing->len);
            g_free(file_path);
            return;
        }
    }
    
    // Determine content type
    const char *content_type = get_mime_type(file_path);
    
    if (soup_server_message_get_method(msg) == SOUP_METHOD_GET) {
        GMappedFile *mapping = g_mapped_file_new(file_path, FALSE, NULL);
        if (!mapping) {
            soup_server_message_set_status(msg, SOUP_STATUS_INTERNAL_SERVER_ERROR, NULL);
            g_free(file_path);
            return;
        }
        
        // Handle range requests and regular requests
        handle_range_request(msg, mapping, content_type, st.st_size);
    } else { // HEAD request
        char *length = g_strdup_printf("%lu", (gulong)st.st_size);
        soup_message_headers_append(soup_server_message_get_response_headers(msg),
                                   "Content-Length", length);
        soup_message_headers_append(soup_server_message_get_response_headers(msg),
                                   "Content-Type", content_type);
        
        // Add Accept-Ranges header for HEAD requests
        soup_message_headers_append(soup_server_message_get_response_headers(msg),
                                   "Accept-Ranges", "bytes");
        g_free(length);
    }
    
    soup_server_message_set_status(msg, SOUP_STATUS_OK, NULL);
    g_free(file_path);
}

// Basic authentication check
static gboolean
basic_auth_callback(SoupAuthDomain *domain, SoupServerMessage *msg,
                   const char *username, const char *password, gpointer data) {
    debug_print("Basic Auth: Checking username=%s password=%s", username, password);
    
    // For testing, accept simple credentials
    if (g_strcmp0(username, "user") == 0 && g_strcmp0(password, "password") == 0) {
        debug_print("Basic Auth: Authentication successful");
        return TRUE;
    }
    
    debug_print("Basic Auth: Authentication failed");
    return FALSE;
}

// Digest authentication check
static gboolean
digest_auth_callback(SoupAuthDomain *domain, SoupServerMessage *msg,
                     const char *username, gpointer data) {
    debug_print("Digest Auth: Checking username=%s", username);
    
    // For testing, accept username "user" with password "password"
    if (g_strcmp0(username, "user") == 0) {
        debug_print("Digest Auth: User found, returning password");
        return GPOINTER_TO_INT(soup_auth_domain_digest_encode_password(username, "Soup Test", "password"));
    }
    
    debug_print("Digest Auth: User not found");
    return FALSE;
}

// WebSocket message received handler
static void
websocket_message_cb(SoupWebsocketConnection *connection,
                    SoupWebsocketDataType type,
                    GBytes *message,
                    gpointer user_data) {
    gsize length;
    const char *data = g_bytes_get_data(message, &length);
    
    debug_print("WebSocket: Received %s message of length %zu",
               type == SOUP_WEBSOCKET_DATA_TEXT ? "text" : "binary", length);
    
    if (type == SOUP_WEBSOCKET_DATA_TEXT) {
        debug_print("WebSocket: Message content: %.*s", (int)length, data);
        
        // Echo message back to client
        char *response = g_strdup_printf("Echo: %.*s", (int)length, data);
        soup_websocket_connection_send_text(connection, response);
        g_free(response);
    } else {
        // Echo binary message back - need to provide proper length
        soup_websocket_connection_send_binary(connection, data, length);
    }
}

// WebSocket closed handler
static void
websocket_closed_cb(SoupWebsocketConnection *connection, gpointer user_data) {
    debug_print("WebSocket: Connection closed");
    
    g_mutex_lock(&websocket_mutex);
    websocket_connections = g_slist_remove(websocket_connections, connection);
    g_mutex_unlock(&websocket_mutex);
    
    g_object_unref(connection);
}

// WebSocket error handler
static void
websocket_error_cb(SoupWebsocketConnection *connection, GError *error, gpointer user_data) {
    debug_print("WebSocket: Error: %s", error->message);
}

// Handle WebSocket requests
static void
websocket_callback(SoupServer *server, SoupServerMessage *msg,
                  const char *path, SoupWebsocketConnection *connection,
                  gpointer user_data) {
    debug_print("WebSocket: Connection established");
    
    // Add to active connections
    g_mutex_lock(&websocket_mutex);
    websocket_connections = g_slist_prepend(websocket_connections, connection);
    g_mutex_unlock(&websocket_mutex);
    
    // Set up event handlers
    g_signal_connect(connection, "message", G_CALLBACK(websocket_message_cb), NULL);
    g_signal_connect(connection, "closed", G_CALLBACK(websocket_closed_cb), NULL);
    g_signal_connect(connection, "error", G_CALLBACK(websocket_error_cb), NULL);
    
    // Send welcome message
    const char *welcome = "Welcome to libsoup WebSocket server!";
    soup_websocket_connection_send_text(connection, welcome);
}

// Handle OPTIONS method for CORS
static void
handle_options(SoupServerMessage *msg, const char *path) {
    SoupMessageHeaders *response_headers = soup_server_message_get_response_headers(msg);
    const char *origin;
    
    // Set standard headers for OPTIONS responses
    soup_server_message_set_status(msg, SOUP_STATUS_OK, NULL);
    soup_message_headers_append(response_headers, "Allow", "GET, POST, HEAD, PUT, DELETE, OPTIONS");
    
    // Add CORS headers if needed
    origin = soup_message_headers_get_one(soup_server_message_get_request_headers(msg), "Origin");
    if (origin) {
        // Allow requests from any origin for this example server
        soup_message_headers_append(response_headers, "Access-Control-Allow-Origin", "*");
        soup_message_headers_append(response_headers, "Access-Control-Allow-Methods", 
                                   "GET, POST, HEAD, PUT, DELETE, OPTIONS");
        soup_message_headers_append(response_headers, "Access-Control-Allow-Headers", 
                                   "Content-Type, Authorization, Range, X-Requested-With");
        soup_message_headers_append(response_headers, "Access-Control-Allow-Credentials", "true");
        soup_message_headers_append(response_headers, "Access-Control-Expose-Headers", 
                                   "Content-Length, Content-Range");
        soup_message_headers_append(response_headers, "Access-Control-Max-Age", "86400");
    }
}

// Main request handler
static void
server_callback(SoupServer *server, SoupServerMessage *msg,
                const char *path, GHashTable *query,
                gpointer user_data) {
    const char *method = soup_server_message_get_method(msg);
    
    debug_print("Received %s request for: %s", method, path);
    print_request_headers(msg);
    
    // Process request cookies
    handle_cookies(msg);
    
    // Set a test cookie in the response
    set_test_cookie(msg);
    
    // Set standard headers for all responses
    SoupMessageHeaders *response_headers = soup_server_message_get_response_headers(msg);
    soup_message_headers_append(response_headers, "Server", "libsoup-test-server/1.0");
    
    // Handle OPTIONS requests properly (for CORS)
    if (g_str_equal(method, "OPTIONS")) {
        handle_options(msg, path);
        return;
    }
    
    // Check if this is a WebSocket upgrade request
    if (websocket_enabled && 
        g_strcmp0(path, "/websocket") == 0 && 
        soup_websocket_server_process_handshake(msg, NULL, NULL, NULL, NULL)) {
        debug_print("WebSocket handshake successful");
        // The server will automatically complete the WebSocket upgrade after sending the response
        return;
    }
    
    // Add CORS headers for non-OPTIONS requests too
    const char *origin = soup_message_headers_get_one(soup_server_message_get_request_headers(msg), "Origin");
    if (origin) {
        soup_message_headers_append(response_headers, "Access-Control-Allow-Origin", "*");
        soup_message_headers_append(response_headers, "Access-Control-Allow-Credentials", "true");
        soup_message_headers_append(response_headers, "Access-Control-Expose-Headers", 
                                   "Content-Length, Content-Range");
    }
    
    // Handle endpoints
    if (g_str_equal(path, "/echo")) {
        if (g_str_equal(method, "HEAD")) {
            // Just set headers for HEAD requests
            soup_message_headers_append(response_headers, "Content-Type", "text/html");
            soup_server_message_set_status(msg, SOUP_STATUS_OK, NULL);
        } else if (g_str_equal(method, "GET")) {
            // Echo request headers and body
            SoupMessageBody *request_body = soup_server_message_get_request_body(msg);
            GString *response = g_string_new("<html><body><h1>Echo</h1><pre>");
            
            g_string_append_printf(response, "Method: %s\n", method);
            g_string_append_printf(response, "Path: %s\n", path);
            g_string_append_printf(response, "HTTP Version: 1.%d\n\n", 
                                soup_server_message_get_http_version(msg));
            
            // Headers
            g_string_append(response, "Headers:\n");
            SoupMessageHeaders *headers = soup_server_message_get_request_headers(msg);
            SoupMessageHeadersIter iter;
            const char *name, *value;
            
            soup_message_headers_iter_init(&iter, headers);
            while (soup_message_headers_iter_next(&iter, &name, &value))
                g_string_append_printf(response, "%s: %s\n", name, value);
            
            // Body
            if (request_body->length > 0) {
                g_string_append(response, "\nBody:\n");
                g_string_append_len(response, request_body->data, request_body->length);
            }
            
            // Query parameters
            if (query && g_hash_table_size(query) > 0) {
                g_string_append(response, "\nQuery Parameters:\n");
                GHashTableIter query_iter;
                gpointer key, val;
                
                g_hash_table_iter_init(&query_iter, query);
                while (g_hash_table_iter_next(&query_iter, &key, &val))
                    g_string_append_printf(response, "%s: %s\n", (char *)key, (char *)val);
            }
            
            g_string_append(response, "</pre></body></html>");
            
            soup_server_message_set_response(msg, "text/html", SOUP_MEMORY_TAKE,
                                    g_string_free(response, FALSE), response->len);
            soup_server_message_set_status(msg, SOUP_STATUS_OK, NULL);
        } else {
            soup_server_message_set_status(msg, SOUP_STATUS_METHOD_NOT_ALLOWED, NULL);
        }
    } else if (g_str_equal(path, "/form")) {
        if (g_str_equal(method, "HEAD")) {
            // Just set headers for HEAD requests
            soup_message_headers_append(response_headers, "Content-Type", "text/html");
            soup_server_message_set_status(msg, SOUP_STATUS_OK, NULL);
        } else if (g_str_equal(method, "GET")) {
            // Serve a form for testing
            const char *form_html = 
                "<html><body>"
                "<h1>Test Form</h1>"
                "<h2>URL-encoded form</h2>"
                "<form method='post' action='/form-handler' enctype='application/x-www-form-urlencoded'>"
                "  <label>Name: <input type='text' name='name' value='Test User'></label><br>"
                "  <label>Email: <input type='email' name='email' value='test@example.com'></label><br>"
                "  <input type='submit' value='Submit URL-encoded Form'>"
                "</form>"
                "<h2>Multipart form</h2>"
                "<form method='post' action='/form-handler' enctype='multipart/form-data'>"
                "  <label>Name: <input type='text' name='name' value='Test User'></label><br>"
                "  <label>Email: <input type='email' name='email' value='test@example.com'></label><br>"
                "  <label>File: <input type='file' name='file'></label><br>"
                "  <input type='submit' value='Submit Multipart Form'>"
                "</form>"
                "<h2>Cookie Test</h2>"
                "<p>This page should set a test cookie. Refresh to see it in action.</p>"
                "<h2>Authentication Tests</h2>"
                "<ul>"
                "  <li><a href='/Basic/'>Basic Auth</a></li>"
                "  <li><a href='/Digest/'>Digest Auth</a></li>"
                "</ul>"
                "<h2>WebSocket Test</h2>"
                "<p><a href='/websocket-client.html'>WebSocket Test Client</a></p>"
                "<h2>Range Request Test</h2>"
                "<p>Try downloading a large file using <code>curl -r 0-1000 http://localhost:8080/path/to/file</code></p>"
                "</body></html>";
            
            soup_server_message_set_response(msg, "text/html", SOUP_MEMORY_COPY,
                                    form_html, strlen(form_html));
            soup_server_message_set_status(msg, SOUP_STATUS_OK, NULL);
        } else {
            soup_server_message_set_status(msg, SOUP_STATUS_METHOD_NOT_ALLOWED, NULL);
        }
    } else if (g_str_equal(path, "/websocket-client.html")) {
        if (g_str_equal(method, "HEAD")) {
            // Just set headers for HEAD requests
            soup_message_headers_append(response_headers, "Content-Type", "text/html");
            soup_server_message_set_status(msg, SOUP_STATUS_OK, NULL);
        } else if (g_str_equal(method, "GET")) {
            // Serve a WebSocket test client
            const char *ws_html = 
                "<html><head><title>WebSocket Test</title>"
                "<script type=\"text/javascript\">"
                "  var ws = null;"
                "  function connect() {"
                "    if (ws !== null) return;"
                "    var host = window.location.hostname;"
                "    var port = window.location.port;"
                "    var wsUrl = 'ws://' + host + ':' + port + '/websocket';"
                "    document.getElementById('status').innerHTML = 'Connecting to ' + wsUrl + '...';"
                "    ws = new WebSocket(wsUrl, ['echo']);"
                "    ws.onopen = function(e) {"
                "      document.getElementById('status').innerHTML = 'Connected!';"
                "    };"
                "    ws.onmessage = function(e) {"
                "      var log = document.getElementById('log');"
                "      log.innerHTML = e.data + '<br>' + log.innerHTML;"
                "    };"
                "    ws.onclose = function(e) {"
                "      document.getElementById('status').innerHTML = 'Disconnected';"
                "      ws = null;"
                "    };"
                "    ws.onerror = function(e) {"
                "      document.getElementById('status').innerHTML = 'Error: ' + e.message;"
                "    };"
                "  }"
                "  function disconnect() {"
                "    if (ws === null) return;"
                "    ws.close();"
                "  }"
                "  function send() {"
                "    if (ws === null) return;"
                "    var message = document.getElementById('message').value;"
                "    ws.send(message);"
                "    document.getElementById('message').value = '';"
                "  }"
                "</script>"
                "</head><body onload=\"connect()\">"
                "<h1>WebSocket Test Client</h1>"
                "<div id=\"status\">Disconnected</div>"
                "<div>"
                "  <input type=\"text\" id=\"message\" placeholder=\"Type a message...\">"
                "  <button onclick=\"send()\">Send</button>"
                "  <button onclick=\"connect()\">Connect</button>"
                "  <button onclick=\"disconnect()\">Disconnect</button>"
                "</div>"
                "<h2>Received Messages:</h2>"
                "<div id=\"log\" style=\"border:1px solid #ccc; padding:10px; height:200px; overflow-y:scroll;\"></div>"
                "</body></html>";
            
            soup_server_message_set_response(msg, "text/html", SOUP_MEMORY_COPY,
                                    ws_html, strlen(ws_html));
            soup_server_message_set_status(msg, SOUP_STATUS_OK, NULL);
        } else {
            soup_server_message_set_status(msg, SOUP_STATUS_METHOD_NOT_ALLOWED, NULL);
        }
    } else if (g_str_equal(path, "/form-handler") && 
              (g_str_equal(method, "POST") || g_str_equal(method, "PUT"))) {
        // Process submitted form data
        handle_form_data(msg);
        
        const char *response_html = 
            "<html><body>"
            "<h1>Form Submitted</h1>"
            "<p>Your form was processed successfully. See server logs for details.</p>"
            "<a href='/form'>Back to form</a>"
            "</body></html>";
        
        soup_server_message_set_response(msg, "text/html", SOUP_MEMORY_COPY,
                                  response_html, strlen(response_html));
        soup_server_message_set_status(msg, SOUP_STATUS_OK, NULL);
    } else if (g_str_equal(method, "GET") || g_str_equal(method, "HEAD")) {
        // Serve static files
        handle_file_request(server, msg, path);
    } else if (g_str_equal(method, "PUT") || g_str_equal(method, "DELETE")) {
        // Just echo for now
        GString *response = g_string_new("<html><body><h1>Not Implemented</h1>");
        g_string_append_printf(response, "<p>%s method received but not fully implemented.</p>", method);
        g_string_append(response, "</body></html>");
        
        soup_server_message_set_response(msg, "text/html", SOUP_MEMORY_TAKE,
                                  g_string_free(response, FALSE), response->len);
        soup_server_message_set_status(msg, SOUP_STATUS_NOT_IMPLEMENTED, NULL);
    } else {
        // Method not supported
        soup_server_message_set_status(msg, SOUP_STATUS_METHOD_NOT_ALLOWED, NULL);
    }
    
    print_response_headers(msg);
    debug_print("Response status: %d %s", 
               soup_server_message_get_status(msg),
               soup_server_message_get_reason_phrase(msg));
}

// Command line options
static GOptionEntry entries[] = {
    { "port", 'p', 0, G_OPTION_ARG_INT, &port, "Port to listen on", "PORT" },
    { "cert-file", 'c', 0, G_OPTION_ARG_STRING, &tls_cert_file, "TLS certificate file", "FILE" },
    { "key-file", 'k', 0, G_OPTION_ARG_STRING, &tls_key_file, "TLS key file", "FILE" },
    { "docroot", 'd', 0, G_OPTION_ARG_STRING, &docroot, "Document root directory", "DIR" },
    { "auth", 'a', 0, G_OPTION_ARG_NONE, &auth_enabled, "Enable authentication", NULL },
    { "no-websocket", 'w', G_OPTION_FLAG_REVERSE, G_OPTION_ARG_NONE, &websocket_enabled, "Disable WebSocket support", NULL },
    { "quiet", 'q', 0, G_OPTION_ARG_NONE, &quiet_mode, "Disable verbose output", NULL },
    { NULL }
};

int
main(int argc, char **argv) {
    signal(SIGUSR1, sig_handler);
    GOptionContext *opts;
    GMainLoop *loop;
    SoupServer *server;
    GError *error = NULL;
    
    // Initialize mime types
    init_mime_types();
    
    // Initialize WebSocket mutex
    g_mutex_init(&websocket_mutex);
    
    // Parse command line options
    opts = g_option_context_new("- LibSoup Test Server");
    g_option_context_add_main_entries(opts, entries, NULL);
    
    if (!g_option_context_parse(opts, &argc, &argv, &error)) {
        g_printerr("Option parsing failed: %s\n", error->message);
        g_error_free(error);
        g_option_context_free(opts);
        return 1;
    }
    
    g_option_context_free(opts);
    
    // Create server
    if (tls_cert_file && tls_key_file) {
        GTlsCertificate *cert;
        
        cert = g_tls_certificate_new_from_files(tls_cert_file, tls_key_file, &error);
        if (error) {
            g_printerr("Unable to create TLS certificate: %s\n", error->message);
            g_error_free(error);
            return 1;
        }
        
        server = soup_server_new("tls-certificate", cert, NULL);
        g_object_unref(cert);
        
        if (!soup_server_listen_all(server, port, SOUP_SERVER_LISTEN_HTTPS, &error)) {
            g_printerr("Unable to create server: %s\n", error->message);
            g_error_free(error);
            g_object_unref(server);
            return 1;
        }
        
        g_print("Secure server (HTTPS) started on port %d\n", port);
    } else {
        server = soup_server_new(NULL, NULL);
        
        if (!soup_server_listen_all(server, port, 0, &error)) {
            g_printerr("Unable to create server: %s\n", error->message);
            g_error_free(error);
            g_object_unref(server);
            return 1;
        }
        
        g_print("Server started on port %d\n", port);
    }
    
    // Setup authentication if enabled
    if (auth_enabled) {
        // Basic authentication
        basic_auth_domain = soup_auth_domain_basic_new(
            "realm", "Soup Test",
            "auth-callback", basic_auth_callback,
            NULL);
        soup_auth_domain_add_path(basic_auth_domain, "/Basic");
        soup_server_add_auth_domain(server, basic_auth_domain);
        
        // Digest authentication
        digest_auth_domain = soup_auth_domain_digest_new(
            "realm", "Soup Test",
            "auth-callback", digest_auth_callback,
            NULL);
        soup_auth_domain_add_path(digest_auth_domain, "/Digest");
        soup_server_add_auth_domain(server, digest_auth_domain);
        
        g_print("Authentication enabled\n");
    }
    
    // Add WebSocket handler if enabled
    if (websocket_enabled) {
        soup_server_add_websocket_handler(server, "/websocket", NULL, NULL, 
                                         websocket_callback, NULL, NULL);
        g_print("WebSocket endpoint enabled at /websocket\n");
    }
    
    // Add request handler
    soup_server_add_handler(server, NULL, server_callback, NULL, NULL);
    
    g_print("Server ready. Available endpoints:\n");
    g_print("  /echo - Echo request details\n");
    g_print("  /form - Test form for cookie and multipart handling\n");
    if (auth_enabled) {
        g_print("  /Basic/* - Protected with Basic authentication\n");
        g_print("  /Digest/* - Protected with Digest authentication\n");
    }
    if (websocket_enabled) {
        g_print("  /websocket - WebSocket endpoint\n");
        g_print("  /websocket-client.html - WebSocket test client\n");
    }
    g_print("  /* - Serve static files from %s\n", docroot ? docroot : "current directory");
    
    // Start main loop
    loop = g_main_loop_new(NULL, TRUE);
    g_main_loop_run(loop);
    
    // Cleanup
    g_main_loop_unref(loop);
    if (auth_enabled) {
        g_object_unref(basic_auth_domain);
        g_object_unref(digest_auth_domain);
    }
    g_hash_table_destroy(mime_types);
    g_mutex_clear(&websocket_mutex);
    g_object_unref(server);
    g_free(docroot);
    
    return 0;
} 