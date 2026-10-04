package httpapi

import (
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"pawmate/server/internal/pairing"
)

// deviceBearerToken extracts an access token without accepting unrelated schemes.
func deviceBearerToken(c *gin.Context) string {
	scheme, token, found := strings.Cut(c.GetHeader("Authorization"), " ")
	if !found || !strings.EqualFold(scheme, "Bearer") {
		return ""
	}
	return strings.TrimSpace(token)
}

// deviceError maps device-service failures to public API errors.
func deviceError(c *gin.Context, err error) {
	status, code := http.StatusInternalServerError, "internal_error"
	switch {
	case errors.Is(err, pairing.ErrInvalidSessionToken):
		status, code = http.StatusUnauthorized, "invalid_session_token"
	case errors.Is(err, pairing.ErrInvalidDeviceCode):
		status, code = http.StatusUnauthorized, "invalid_device_code"
	case errors.Is(err, pairing.ErrNotPaired):
		status, code = http.StatusConflict, "not_paired"
	case errors.Is(err, pairing.ErrDeviceNotFound):
		status, code = http.StatusNotFound, "device_not_found"
	}
	c.JSON(status, gin.H{"error": code})
}

// devicesHandler lists this member's sessions without exposing any credentials.
func devicesHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		devices, err := service.Devices(deviceBearerToken(c))
		if err != nil {
			deviceError(c, err)
			return
		}
		c.JSON(http.StatusOK, gin.H{"devices": devices})
	}
}

// revokeDeviceHandler revokes only devices owned by the authenticated member.
func revokeDeviceHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		if err := service.RevokeDevice(deviceBearerToken(c), c.Param("id")); err != nil {
			deviceError(c, err)
			return
		}
		c.Status(http.StatusNoContent)
	}
}

// deviceLoginCodeHandler issues a short-lived, single-use additional-device code.
func deviceLoginCodeHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		code, err := service.CreateDeviceLoginCode(deviceBearerToken(c))
		if err != nil {
			deviceError(c, err)
			return
		}
		c.JSON(http.StatusCreated, code)
	}
}

// redeemDeviceLoginCodeHandler exchanges a code for an independent device token.
func redeemDeviceLoginCodeHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		var request struct {
			Code       string `json:"code" binding:"required"`
			DeviceName string `json:"device_name" binding:"max=80"`
		}
		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
			return
		}
		credentials, err := service.RedeemDeviceLoginCode(request.Code, request.DeviceName)
		if err != nil {
			deviceError(c, err)
			return
		}
		c.JSON(http.StatusOK, credentials)
	}
}
