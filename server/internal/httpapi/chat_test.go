package httpapi

import (
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"testing"

	"pawmate/server/internal/config"
	"pawmate/server/internal/pairing"
)

func TestChatHTTPAuthenticationAndReadFlow(t *testing.T) {
	service := pairing.NewService()
	defer service.Close()
	invite, err := service.CreateInvite("https://home.example.test")
	if err != nil {
		t.Fatal(err)
	}
	link, _ := url.Parse(invite.URL)
	partner, err := service.RedeemInvite(link.Query().Get("code"))
	if err != nil {
		t.Fatal(err)
	}
	router := NewRouter(config.Config{Environment: "test"}, slog.New(slog.NewTextHandler(testLogWriter{}, nil)), service)
	unauthorized := performJSONRequest(t, router, http.MethodGet, "/api/v1/chat/messages", "", "")
	if unauthorized.Code != http.StatusUnauthorized {
		t.Fatal("unauthenticated history is accessible")
	}
	response := performJSONRequest(t, router, http.MethodPost, "/api/v1/chat/messages", `{"client_id":"first","text":"你好 🐾","sender":"invitee"}`, "Bearer "+invite.InviterToken)
	if response.Code != http.StatusOK {
		t.Fatalf("send status = %d", response.Code)
	}
	var message pairing.Message
	decodeJSON(t, response, &message)
	if message.Sender != "inviter" || message.Text != "你好 🐾" {
		t.Fatal("sender can be spoofed or Unicode is damaged")
	}
	response = performJSONRequest(t, router, http.MethodGet, "/api/v1/chat/messages", "", "Bearer "+partner.InviteeToken)
	if response.Header().Get("Cache-Control") != "no-store" {
		t.Fatal("private message responses can be cached")
	}
	var page pairing.MessagePage
	decodeJSON(t, response, &page)
	if page.UnreadCount != 1 || page.PartnerReadID != 0 {
		t.Fatal("unread metadata incorrect")
	}
	response = performJSONRequest(t, router, http.MethodPost, "/api/v1/chat/read", `{"message_id":1}`, "Bearer "+partner.InviteeToken)
	if response.Code != http.StatusOK {
		t.Fatal("read acknowledgment failed")
	}
	response = performJSONRequest(t, router, http.MethodGet, "/api/v1/chat/messages?after_id=1", "", "Bearer "+invite.InviterToken)
	decodeJSON(t, response, &page)
	if page.PartnerReadID != message.ID || len(page.Messages) != 0 {
		t.Fatal("receipt-only update failed")
	}
	for _, query := range []string{"limit=0", "limit=101", "after_id=-1", "after_id=1&before_id=2", "before_id=oops"} {
		response = performJSONRequest(t, router, http.MethodGet, "/api/v1/chat/messages?"+query, "", "Bearer "+invite.InviterToken)
		if response.Code != http.StatusBadRequest {
			t.Fatal("invalid pagination accepted", query)
		}
	}
	response = performJSONRequest(t, router, http.MethodPost, "/api/v1/chat/messages", `{"client_id":"large","text":"`+strings.Repeat("x", 4001)+`"}`, "Bearer "+invite.InviterToken)
	if response.Code != http.StatusBadRequest {
		t.Fatal("oversized message accepted")
	}
}
