package httpapi

import (
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"pawmate/server/internal/pairing"
)

type createInviteRequest struct {
	Profile    *pairing.Profile `json:"profile" binding:"required"`
	ServerURL  string           `json:"server_url" binding:"required"`
	DeviceName string           `json:"device_name" binding:"max=80"`
}

type createInviteResponse struct {
	ExpiresAt    string `json:"expires_at"`
	InviteURL    string `json:"invite_url"`
	InviterToken string `json:"inviter_token"`
	RecoveryCode string `json:"recovery_code"`
}

type redeemInviteRequest struct {
	Profile    *pairing.Profile `json:"profile" binding:"required"`
	Code       string           `json:"code" binding:"required"`
	DeviceName string           `json:"device_name" binding:"max=80"`
}

type pairingStatusResponse struct {
	InviteeToken string `json:"invitee_token,omitempty"`
	RecoveryCode string `json:"recovery_code,omitempty"`
	PairID       string `json:"pair_id,omitempty"`
	Status       string `json:"status"`
}

type recoverPairingRequest struct {
	RecoveryCode string `json:"recovery_code" binding:"required"`
	DeviceName   string `json:"device_name" binding:"max=80"`
}

type recoverPairingResponse struct {
	AccessToken  string `json:"access_token"`
	PairID       string `json:"pair_id"`
	RecoveryCode string `json:"recovery_code"`
	Role         string `json:"role"`
}

type pairingSessionResponse struct {
	Profile *pairing.Profile `json:"profile,omitempty"`
	Partner *pairing.Profile `json:"partner,omitempty"`
	PairID  string           `json:"pair_id,omitempty"`
	Role    string           `json:"role"`
	Status  string           `json:"status"`
}

// createInviteHandler creates an invitation for the configured server URL.
func createInviteHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 400*1024)
		var request createInviteRequest
		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
			return
		}

		invite, err := service.CreateInviteWithProfile(request.ServerURL, request.DeviceName, *request.Profile)
		if err != nil {
			status := http.StatusInternalServerError
			code := "internal_error"
			switch {
			case errors.Is(err, pairing.ErrInvalidProfile):
				status, code = http.StatusBadRequest, "invalid_profile"
			case errors.Is(err, pairing.ErrInvalidServerURL):
				status, code = http.StatusBadRequest, "invalid_server_url"
			case errors.Is(err, pairing.ErrAlreadyPaired):
				status, code = http.StatusConflict, "already_paired"
			case errors.Is(err, pairing.ErrInvitePending):
				status, code = http.StatusConflict, "invite_pending"
			}
			c.JSON(status, gin.H{"error": code})
			return
		}

		c.JSON(http.StatusCreated, createInviteResponse{
			ExpiresAt:    invite.ExpiresAt.UTC().Format("2006-01-02T15:04:05Z"),
			InviteURL:    invite.URL,
			InviterToken: invite.InviterToken,
			RecoveryCode: invite.RecoveryCode,
		})
	}
}

// redeemInviteHandler consumes the one-time code supplied by the invitee.
func redeemInviteHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 400*1024)
		var request redeemInviteRequest
		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
			return
		}

		status, err := service.RedeemInviteWithProfile(request.Code, request.DeviceName, *request.Profile)
		if err != nil {
			code := "invalid_invite"
			httpStatus := http.StatusConflict
			if errors.Is(err, pairing.ErrInvalidProfile) {
				code, httpStatus = "invalid_profile", http.StatusBadRequest
			} else if errors.Is(err, pairing.ErrExpiredInvite) {
				code, httpStatus = "expired_invite", http.StatusGone
			} else if !errors.Is(err, pairing.ErrInvalidInvite) {
				code, httpStatus = "internal_error", http.StatusInternalServerError
			}
			c.JSON(httpStatus, gin.H{"error": code})
			return
		}

		c.JSON(http.StatusOK, pairingStatusResponse{
			InviteeToken: status.InviteeToken,
			RecoveryCode: status.RecoveryCode,
			PairID:       status.PairID,
			Status:       status.Status,
		})
	}
}

// recoverPairingHandler rotates a member's credentials using their recovery code.
func recoverPairingHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		var request recoverPairingRequest
		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
			return
		}

		credentials, err := service.Recover(request.RecoveryCode, request.DeviceName)
		if err != nil {
			code := "invalid_recovery_code"
			status := http.StatusUnauthorized
			if errors.Is(err, pairing.ErrNotPaired) {
				code, status = "not_paired", http.StatusConflict
			} else if !errors.Is(err, pairing.ErrInvalidRecoveryCode) {
				code, status = "internal_error", http.StatusInternalServerError
			}
			c.JSON(status, gin.H{"error": code})
			return
		}

		c.JSON(http.StatusOK, recoverPairingResponse{
			AccessToken:  credentials.AccessToken,
			PairID:       credentials.PairID,
			RecoveryCode: credentials.RecoveryCode,
			Role:         credentials.Role,
		})
	}
}

// pairingSessionHandler validates either member's access token.
func pairingSessionHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Cache-Control", "no-store")
		token := strings.TrimSpace(strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer "))
		session, err := service.SessionWithProfiles(token)
		if err != nil {
			if errors.Is(err, pairing.ErrInvalidSessionToken) {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid_session_token"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal_error"})
			return
		}
		c.JSON(http.StatusOK, pairingSessionResponse{
			Profile: session.Profile,
			Partner: session.Partner,
			PairID:  session.PairID,
			Role:    session.Role,
			Status:  session.Status,
		})
	}
}

// pairingStatusHandler reports state to the device that created the invite.
func pairingStatusHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := strings.TrimSpace(strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer "))
		status, err := service.Status(token)
		if err != nil {
			if errors.Is(err, pairing.ErrInvalidInviterToken) {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid_inviter_token"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal_error"})
			return
		}
		c.JSON(http.StatusOK, pairingStatusResponse{PairID: status.PairID, Status: status.Status})
	}
}
