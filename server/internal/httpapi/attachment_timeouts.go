package httpapi

import (
	"errors"
	"net/http"
	"time"
)

const (
	attachmentReadTimeout  = 75 * time.Second
	attachmentWriteTimeout = 90 * time.Second
)

// WithAttachmentTimeouts extends only upload deadlines, before Gin wraps the writer.
// Server header, ordinary request and idle deadlines remain unchanged. The write
// budget includes body upload and processing, and matches the client's 90s wait.
func WithAttachmentTimeouts(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost && r.URL.Path == "/api/v1/chat/attachments" {
			controller := http.NewResponseController(w)
			now := time.Now()
			for _, err := range []error{
				controller.SetReadDeadline(now.Add(attachmentReadTimeout)),
				controller.SetWriteDeadline(now.Add(attachmentWriteTimeout)),
			} {
				// In-memory ResponseRecorders have no transport deadlines. Real
				// net/http HTTP/1 and HTTP/2 writers support these operations.
				if err != nil && !errors.Is(err, http.ErrNotSupported) {
					http.Error(w, "could not configure upload deadlines", http.StatusInternalServerError)
					return
				}
			}
		}
		next.ServeHTTP(w, r)
	})
}
