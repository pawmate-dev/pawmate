package httpapi

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"pawmate/server/internal/config"
	"pawmate/server/internal/pairing"
)

// NewRouter creates the versioned HTTP API served by a Pawmate instance.
func NewRouter(cfg config.Config, logger *slog.Logger) *gin.Engine {
	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	router.Use(gin.LoggerWithFormatter(func(param gin.LogFormatterParams) string {
		logger.Info("http request",
			"status", param.StatusCode,
			"method", param.Method,
			"path", param.Path,
			"latency", param.Latency.Round(time.Millisecond),
			"client_ip", param.ClientIP,
		)
		return ""
	}), gin.Recovery())

	router.GET("/healthz", healthHandler)
	pairingService := pairing.NewService()
	api := router.Group("/api/v1")
	api.GET("/instance", instanceHandler(cfg))
	api.POST("/pairing/invites", createInviteHandler(pairingService))
	api.POST("/pairing/invites/redeem", redeemInviteHandler(pairingService))
	api.GET("/pairing/invites/status", pairingStatusHandler(pairingService))

	return router
}

// healthHandler reports that the HTTP process is reachable.
func healthHandler(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
