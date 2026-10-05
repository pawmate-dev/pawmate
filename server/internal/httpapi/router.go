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
func NewRouter(cfg config.Config, logger *slog.Logger, pairingService *pairing.Service) *gin.Engine {
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
	api := router.Group("/api/v1")
	api.GET("/instance", instanceHandler(cfg))
	api.POST("/pairing/invites", createInviteHandler(pairingService))
	api.POST("/pairing/invites/redeem", redeemInviteHandler(pairingService))
	api.GET("/pairing/invites/status", pairingStatusHandler(pairingService))
	api.POST("/pairing/recover", recoverPairingHandler(pairingService))
	api.GET("/pairing/session", pairingSessionHandler(pairingService))
	api.GET("/pairing/devices", devicesHandler(pairingService))
	api.DELETE("/pairing/devices/:id", revokeDeviceHandler(pairingService))
	api.POST("/pairing/devices/login-codes", deviceLoginCodeHandler(pairingService))
	api.POST("/pairing/devices/login-codes/redeem", redeemDeviceLoginCodeHandler(pairingService))
	chat := api.Group("/chat")
	chat.Use(func(c *gin.Context) { c.Header("Cache-Control", "no-store"); c.Next() })
	chat.GET("/messages", chatMessagesHandler(pairingService))
	chat.POST("/messages", sendChatMessageHandler(pairingService))
	chat.POST("/read", readChatMessagesHandler(pairingService))
	chat.POST("/attachments", sendAttachmentHandler(pairingService))
	chat.GET("/attachments/:id", downloadAttachmentHandler(pairingService))

	return router
}

// healthHandler reports that the HTTP process is reachable.
func healthHandler(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
