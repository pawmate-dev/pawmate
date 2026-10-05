package httpapi

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"image"
	"image/png"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"pawmate/server/internal/config"
	"pawmate/server/internal/pairing"
)

func TestPairingHTTPFlow(t *testing.T) {
	service, err := pairing.OpenService(":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer service.Close()
	router := NewRouter(config.Config{
		Environment:  "test",
		InstanceID:   "test-instance",
		InstanceName: "Test Home",
		Port:         "8080",
	}, slog.New(slog.NewTextHandler(testLogWriter{}, nil)), service)

	createResponse := performJSONRequest(t, router, http.MethodPost, "/api/v1/pairing/invites", profileRequest(t, map[string]string{"server_url": "https://home.example.test"}, "Ash"), "")
	if createResponse.Code != http.StatusCreated {
		t.Fatalf("create status = %d, want %d", createResponse.Code, http.StatusCreated)
	}
	var invite struct {
		InviteURL    string `json:"invite_url"`
		InviterToken string `json:"inviter_token"`
		RecoveryCode string `json:"recovery_code"`
	}
	decodeJSON(t, createResponse, &invite)
	if invite.InviteURL == "" || invite.InviterToken == "" || invite.RecoveryCode == "" {
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
	redeemResponse := performJSONRequest(t, router, http.MethodPost, "/api/v1/pairing/invites/redeem", profileRequest(t, map[string]string{"code": code}, "Fern"), "")
	if redeemResponse.Code != http.StatusOK {
		t.Fatalf("redeem status = %d, want %d", redeemResponse.Code, http.StatusOK)
	}
	statusResponse = performJSONRequest(t, router, http.MethodGet, "/api/v1/pairing/invites/status", "", "Bearer "+invite.InviterToken)
	if !strings.Contains(statusResponse.Body.String(), `"status":"paired"`) {
		t.Fatalf("paired status = %s", statusResponse.Body.String())
	}
	var partner struct {
		Token string `json:"invitee_token"`
	}
	decodeJSON(t, redeemResponse, &partner)
	unauthorized := performJSONRequest(t, router, http.MethodPost, "/api/v1/pairing/devices/login-codes", "", "")
	if unauthorized.Code != http.StatusUnauthorized {
		t.Fatal("unauthenticated device can issue a login code")
	}
	loginResponse := performJSONRequest(t, router, http.MethodPost, "/api/v1/pairing/devices/login-codes", "", "Bearer "+invite.InviterToken)
	if loginResponse.Code != http.StatusCreated {
		t.Fatalf("create device login status: %d", loginResponse.Code)
	}
	var login struct {
		Code string `json:"code"`
	}
	decodeJSON(t, loginResponse, &login)
	deviceResponse := performJSONRequest(t, router, http.MethodPost, "/api/v1/pairing/devices/login-codes/redeem", `{"code":"`+login.Code+`","device_name":"Tablet"}`, "")
	if deviceResponse.Code != http.StatusOK {
		t.Fatalf("device sign-in status: %d", deviceResponse.Code)
	}
	if strings.Contains(deviceResponse.Body.String(), "recovery_code") {
		t.Fatal("device sign-in disclosed recovery secret")
	}
	var tablet struct {
		Token string `json:"access_token"`
	}
	decodeJSON(t, deviceResponse, &tablet)
	for _, token := range []string{invite.InviterToken, tablet.Token, partner.Token} {
		response := performJSONRequest(t, router, http.MethodGet, "/api/v1/pairing/session", "", "Bearer "+token)
		if response.Code != http.StatusOK {
			t.Fatal("adding a device invalidated a member session")
		}
		var session struct {
			Profile pairing.Profile `json:"profile"`
			Partner pairing.Profile `json:"partner"`
		}
		decodeJSON(t, response, &session)
		if session.Profile.Nickname == "" || session.Partner.Nickname == "" || session.Profile.Nickname == session.Partner.Nickname {
			t.Fatal("session did not restore both distinct member identities")
		}
	}
	devicesResponse := performJSONRequest(t, router, http.MethodGet, "/api/v1/pairing/devices", "", "Bearer "+tablet.Token)
	var devices struct {
		Devices []pairing.Device `json:"devices"`
	}
	decodeJSON(t, devicesResponse, &devices)
	if len(devices.Devices) != 2 {
		t.Fatal("device list leaked partner's devices or lost own device")
	}
	if strings.Contains(devicesResponse.Body.String(), "token") || strings.Contains(devicesResponse.Body.String(), "recovery") {
		t.Fatal("device list disclosed credentials")
	}
	var phoneID string
	for _, device := range devices.Devices {
		if !device.Current {
			phoneID = device.ID
		}
	}
	forbidden := performJSONRequest(t, router, http.MethodDelete, "/api/v1/pairing/devices/"+phoneID, "", "Bearer "+partner.Token)
	if forbidden.Code != http.StatusNotFound {
		t.Fatal("partner could revoke another member's device")
	}
	revoked := performJSONRequest(t, router, http.MethodDelete, "/api/v1/pairing/devices/"+phoneID, "", "Bearer "+tablet.Token)
	if revoked.Code != http.StatusNoContent {
		t.Fatalf("revoke status: %d", revoked.Code)
	}
	rejected := performJSONRequest(t, router, http.MethodGet, "/api/v1/pairing/session", "", "Bearer "+invite.InviterToken)
	if rejected.Code != http.StatusUnauthorized {
		t.Fatal("revoked token still authenticates")
	}
}

// profileRequest creates a real PNG fixture, avoiding a test-only validation bypass.
func profileRequest(t *testing.T, fields map[string]string, nickname string) string {
	t.Helper()
	var imageBytes bytes.Buffer
	if err := png.Encode(&imageBytes, image.NewRGBA(image.Rect(0, 0, 8, 8))); err != nil {
		t.Fatal(err)
	}
	body := map[string]any{"profile": pairing.Profile{Nickname: nickname, AvatarBase64: base64.StdEncoding.EncodeToString(imageBytes.Bytes())}}
	for key, value := range fields {
		body[key] = value
	}
	data, err := json.Marshal(body)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func TestInvitationRequiresValidProfile(t *testing.T) {
	service := pairing.NewService()
	defer service.Close()
	router := NewRouter(config.Config{Environment: "test"}, slog.New(slog.NewTextHandler(testLogWriter{}, nil)), service)
	for _, body := range []string{
		`{"server_url":"https://home.example.test"}`,
		`{"server_url":"https://home.example.test","profile":{"nickname":"Ash","avatar_base64":"garbage"}}`,
		profileRequest(t, map[string]string{"server_url": "https://home.example.test"}, "  "),
	} {
		response := performJSONRequest(t, router, http.MethodPost, "/api/v1/pairing/invites", body, "")
		if response.Code != http.StatusBadRequest {
			t.Fatalf("invalid profile accepted: %d", response.Code)
		}
	}
	create := performJSONRequest(t, router, http.MethodPost, "/api/v1/pairing/invites", profileRequest(t, map[string]string{"server_url": "https://home.example.test"}, "Ash"), "")
	if create.Code != http.StatusCreated {
		t.Fatal("invalid requests reserved the instance")
	}
	var invite struct {
		URL string `json:"invite_url"`
	}
	decodeJSON(t, create, &invite)
	uri, _ := url.Parse(invite.URL)
	code := uri.Query().Get("code")
	response := performJSONRequest(t, router, http.MethodPost, "/api/v1/pairing/invites/redeem", `{"code":"`+code+`"}`, "")
	if response.Code != http.StatusBadRequest {
		t.Fatal("redemption without profile accepted")
	}
	response = performJSONRequest(t, router, http.MethodPost, "/api/v1/pairing/invites/redeem", profileRequest(t, map[string]string{"code": code}, "Fern"), "")
	if response.Code != http.StatusOK {
		t.Fatal("invalid redemption consumed the invitation")
	}
	response = performJSONRequest(t, router, http.MethodGet, "/api/v1/pairing/session", "", "")
	if response.Code != http.StatusUnauthorized || strings.Contains(response.Body.String(), "avatar_base64") {
		t.Fatal("profile leaked without credentials")
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
