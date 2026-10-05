package httpapi

import (
	"bytes"
	"log/slog"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"pawmate/server/internal/config"
	"pawmate/server/internal/pairing"
)

func TestAuthenticatedAttachmentHTTP(t *testing.T) {
	service := pairing.NewService()
	defer service.Close()
	invite, _ := service.CreateInvite("https://home.example.test")
	link, _ := url.Parse(invite.URL)
	partner, err := service.RedeemInvite(link.Query().Get("code"))
	if err != nil {
		t.Fatal(err)
	}
	router := NewRouter(config.Config{Environment: "test"}, slog.New(slog.NewTextHandler(testLogWriter{}, nil)), service)
	upload := func(token string) *httptest.ResponseRecorder {
		var body bytes.Buffer
		writer := multipart.NewWriter(&body)
		writer.WriteField("client_id", "file-id")
		writer.WriteField("kind", "file")
		file, _ := writer.CreateFormFile("file", "note.txt")
		file.Write([]byte("private content"))
		writer.Close()
		request := httptest.NewRequest(http.MethodPost, "/api/v1/chat/attachments", &body)
		request.Header.Set("Content-Type", writer.FormDataContentType())
		request.Header.Set("Authorization", "Bearer "+token)
		response := httptest.NewRecorder()
		router.ServeHTTP(response, request)
		return response
	}
	if upload("").Code != http.StatusUnauthorized {
		t.Fatal("anonymous upload accepted")
	}
	sent := upload(invite.InviterToken)
	if sent.Code != http.StatusOK {
		t.Fatal("upload failed", sent.Code)
	}
	var message pairing.Message
	decodeJSON(t, sent, &message)
	if message.Attachment == nil || message.Sender != "inviter" {
		t.Fatal("metadata or sender missing")
	}
	if upload(invite.InviterToken).Code != http.StatusOK {
		t.Fatal("retry failed")
	}
	unauthorized := performJSONRequest(t, router, http.MethodGet, "/api/v1/chat/attachments/1", "", "")
	if unauthorized.Code != http.StatusUnauthorized {
		t.Fatal("anonymous download accepted")
	}
	downloaded := performJSONRequest(t, router, http.MethodGet, "/api/v1/chat/attachments/1", "", "Bearer "+partner.InviteeToken)
	if downloaded.Code != http.StatusOK || downloaded.Body.String() != "private content" || downloaded.Header().Get("Cache-Control") != "no-store" || downloaded.Header().Get("X-Content-Type-Options") != "nosniff" || downloaded.Header().Get("Content-Type") != "application/octet-stream" {
		t.Fatal("unsafe or corrupted download")
	}
	if downloaded.Header().Get("Content-Disposition") == "" {
		t.Fatal("missing download filename")
	}
}
