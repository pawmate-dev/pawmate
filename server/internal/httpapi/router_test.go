package httpapi

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"pawmate/server/internal/config"
)

func TestHealthz(t *testing.T) {
	router := testRouter()
	response := httptest.NewRecorder()

	router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/healthz", nil))

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
}

func TestInstance(t *testing.T) {
	router := testRouter()
	response := httptest.NewRecorder()

	router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/api/v1/instance", nil))

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	if got, want := response.Body.String(), `{"api_version":"v1","features":["pairing"],"id":"test-instance","name":"Test Home","registration":"closed"}`; got != want {
		t.Fatalf("response = %s, want %s", got, want)
	}
}

func testRouter() http.Handler {
	return NewRouter(config.Config{
		Environment:  "test",
		InstanceID:   "test-instance",
		InstanceName: "Test Home",
		Port:         "8080",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)))
}
