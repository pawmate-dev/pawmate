package httpapi

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"pawmate/server/internal/config"
)

func TestPairingHTTPFlow(t *testing.T) {
	router := NewRouter(config.Config{
		Environment:  "test",
		InstanceID:   "test-instance",
		InstanceName: "Test Home",
		Port:         "8080",
	}, slog.New(slog.NewTextHandler(testLogWriter{}, nil)))

	createResponse := performJSONRequest(t, router, http.MethodPost, "/api/v1/pairing/invites", `{"server_url":"https://home.example.test"}`, "")
	if createResponse.Code != http.StatusCreated {
		t.Fatalf("create status = %d, want %d", createResponse.Code, http.StatusCreated)
	}
	var invite struct {
		InviteURL    string `json:"invite_url"`
		InviterToken string `json:"inviter_token"`
	}
	decodeJSON(t, createResponse, &invite)
	if invite.InviteURL == "" || invite.InviterToken == "" {
		t.Fatalf("create response did not contain invite credentials: %+v", invite)
	}

	statusResponse := performJSONRequest(t, router, http.MethodGet, "/api/v1/pairing/invites/status", "", "Bearer "+invite.InviterToken)
	if statusResponse.Code != http.StatusOK {
		t.Fatalf("pending status = %d, want %d", statusResponse.Code, http.StatusOK)
	}

	inviteURL, err := url.Parse(invite.InviteURL)
	if err != nil {
		t.Fatal(err)
	}
	code := inviteURL.Query().Get("code")
	redeemResponse := performJSONRequest(t, router, http.MethodPost, "/api/v1/pairing/invites/redeem", `{"code":"`+code+`"}`, "")
	if redeemResponse.Code != http.StatusOK {
		t.Fatalf("redeem status = %d, want %d", redeemResponse.Code, http.StatusOK)
	}
	statusResponse = performJSONRequest(t, router, http.MethodGet, "/api/v1/pairing/invites/status", "", "Bearer "+invite.InviterToken)
	if !strings.Contains(statusResponse.Body.String(), `"status":"paired"`) {
		t.Fatalf("paired status = %s", statusResponse.Body.String())
	}
}

func performJSONRequest(t *testing.T, handler http.Handler, method, path, body, authorization string) *httptest.ResponseRecorder {
	t.Helper()
	request := httptest.NewRequest(method, path, strings.NewReader(body))
	if body != "" {
		request.Header.Set("Content-Type", "application/json")
	}
	if authorization != "" {
		request.Header.Set("Authorization", authorization)
	}
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response
}

func decodeJSON(t *testing.T, response *httptest.ResponseRecorder, target any) {
	t.Helper()
	if err := json.NewDecoder(response.Body).Decode(target); err != nil {
		t.Fatal(err)
	}
}

type testLogWriter struct{}

func (testLogWriter) Write(data []byte) (int, error) { return len(data), nil }
