package httpapi

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"testing"
	"time"

	"pawmate/server/internal/config"
	"pawmate/server/internal/pairing"
)

type deadlineWriter struct {
	*httptest.ResponseRecorder
	read, write time.Time
}

func (w *deadlineWriter) SetReadDeadline(deadline time.Time) error {
	w.read = deadline
	return nil
}

func (w *deadlineWriter) SetWriteDeadline(deadline time.Time) error {
	w.write = deadline
	return nil
}

func TestUploadDeadlineScope(t *testing.T) {
	for _, test := range []struct {
		method, path string
		extended     bool
	}{
		{http.MethodPost, "/api/v1/chat/attachments", true},
		{http.MethodPost, "/api/v1/chat/attachments?ignored=1", true},
		{http.MethodGet, "/api/v1/chat/attachments/1", false},
		{http.MethodPost, "/api/v1/chat/messages", false},
		{http.MethodPost, "/api/v1/chat/attachments/other", false},
	} {
		t.Run(test.method+test.path, func(t *testing.T) {
			writer := &deadlineWriter{ResponseRecorder: httptest.NewRecorder()}
			start := time.Now()
			WithAttachmentTimeouts(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if test.extended {
					if writer.read.Before(start.Add(attachmentReadTimeout)) || writer.write.Before(start.Add(attachmentWriteTimeout)) {
						t.Fatal("deadline not extended before handler")
					}
				} else if !writer.read.IsZero() || !writer.write.IsZero() {
					t.Fatal("ordinary request deadline changed")
				}
				w.WriteHeader(http.StatusNoContent)
			})).ServeHTTP(writer, httptest.NewRequest(test.method, test.path, nil))
			if writer.Code != http.StatusNoContent {
				t.Fatal(writer.Code)
			}
		})
	}
}

type failedUploadBody struct{ err error }

func (body failedUploadBody) Read([]byte) (int, error) { return 0, body.err }

func TestUploadBodyErrors(t *testing.T) {
	service := pairing.NewService()
	defer service.Close()
	invite, err := service.CreateInvite("https://home.example.test")
	if err != nil {
		t.Fatal(err)
	}
	link, _ := url.Parse(invite.URL)
	if _, err := service.RedeemInvite(link.Query().Get("code")); err != nil {
		t.Fatal(err)
	}
	router := NewRouter(config.Config{Environment: "test"}, slog.New(slog.NewTextHandler(testLogWriter{}, nil)), service)
	for _, test := range []struct {
		name string
		err  error
		code int
		body string
	}{
		{"timeout", os.ErrDeadlineExceeded, http.StatusRequestTimeout, `{"error":"upload_timeout"}`},
		{"oversized", &http.MaxBytesError{Limit: pairing.MaxAttachmentBytes}, http.StatusRequestEntityTooLarge, `{"error":"attachment_too_large"}`},
		{"malformed", io.ErrUnexpectedEOF, http.StatusBadRequest, `{"error":"invalid_attachment"}`},
	} {
		t.Run(test.name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodPost, "/api/v1/chat/attachments", failedUploadBody{test.err})
			request.Header.Set("Authorization", "Bearer "+invite.InviterToken)
			request.Header.Set("Content-Type", "multipart/form-data; boundary=example")
			response := httptest.NewRecorder()
			router.ServeHTTP(response, request)
			if response.Code != test.code || response.Body.String() != test.body {
				t.Fatalf("got %d %s", response.Code, response.Body.String())
			}
			if test.code == http.StatusRequestTimeout && response.Header().Get("Connection") != "close" {
				t.Fatal("timed-out HTTP/1 connection must not be reused")
			}
		})
	}
}

// The real transport must allow a body slower than both original server deadlines.
func TestSlowUploadOverHTTP(t *testing.T) {
	service := pairing.NewService()
	defer service.Close()
	invite, err := service.CreateInvite("https://home.example.test")
	if err != nil {
		t.Fatal(err)
	}
	link, _ := url.Parse(invite.URL)
	if _, err := service.RedeemInvite(link.Query().Get("code")); err != nil {
		t.Fatal(err)
	}
	router := NewRouter(config.Config{Environment: "test"}, slog.New(slog.NewTextHandler(testLogWriter{}, nil)), service)
	ordinaryStarted := make(chan struct{}, 1)
	ordinaryFailed := make(chan bool, 1)
	server := httptest.NewUnstartedServer(WithAttachmentTimeouts(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/ordinary" {
			ordinaryStarted <- struct{}{}
			_, err := io.Copy(io.Discard, r.Body)
			ordinaryFailed <- os.IsTimeout(err)
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		router.ServeHTTP(w, r)
	})))
	server.Config.ReadTimeout = 150 * time.Millisecond
	server.Config.WriteTimeout = 250 * time.Millisecond
	server.Start()
	defer server.Close()
	client := server.Client()
	client.Timeout = 5 * time.Second

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	writer.WriteField("client_id", "slow-upload")
	writer.WriteField("kind", "file")
	file, err := writer.CreateFormFile("file", "slow.txt")
	if err != nil {
		t.Fatal(err)
	}
	// Send headers and fields promptly, then delay actual file bytes.
	split := body.Len()
	file.Write([]byte("content uploaded slowly"))
	writer.Close()
	reader, pipe := io.Pipe()
	defer reader.Close()
	go func() {
		defer pipe.Close()
		if _, err := pipe.Write(body.Bytes()[:split]); err != nil {
			return
		}
		time.Sleep(400 * time.Millisecond)
		pipe.Write(body.Bytes()[split:])
	}()
	request, _ := http.NewRequest(http.MethodPost, server.URL+"/api/v1/chat/attachments", reader)
	request.Header.Set("Authorization", "Bearer "+invite.InviterToken)
	request.Header.Set("Content-Type", writer.FormDataContentType())
	response, err := client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	data, err := io.ReadAll(response.Body)
	response.Body.Close()
	if err != nil || response.StatusCode != http.StatusOK {
		t.Fatalf("slow upload failed: status=%d error=%v body=%s", response.StatusCode, err, data)
	}
	var message pairing.Message
	if err := json.Unmarshal(data, &message); err != nil {
		t.Fatal(err)
	}
	if message.Attachment == nil {
		t.Fatal("attachment was not stored")
	}

	// Even on a reused HTTP/1 connection, the next ordinary body still times out.
	ordinaryReader, ordinaryPipe := io.Pipe()
	defer ordinaryReader.Close()
	request, _ = http.NewRequest(http.MethodPost, server.URL+"/ordinary", ordinaryReader)
	go func() {
		defer ordinaryPipe.Close()
		select {
		case <-ordinaryStarted:
			time.Sleep(400 * time.Millisecond)
			ordinaryPipe.Write([]byte("late ordinary body"))
		case <-time.After(3 * time.Second):
		}
	}()
	response, err = client.Do(request)
	if err == nil {
		io.Copy(io.Discard, response.Body)
		response.Body.Close()
	}
	select {
	case timedOut := <-ordinaryFailed:
		if !timedOut {
			t.Fatal("upload deadline leaked into ordinary request")
		}
	case <-time.After(3 * time.Second):
		t.Fatal("ordinary request did not retain short timeout")
	}
}
