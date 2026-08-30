package httpapi

import (
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"pawmate/server/internal/pairing"
)

type createInviteRequest struct {
	ServerURL string `json:"server_url" binding:"required"`
}

type createInviteResponse struct {
	ExpiresAt    string `json:"expires_at"`
	InviteURL    string `json:"invite_url"`
	InviterToken string `json:"inviter_token"`
}

type redeemInviteRequest struct {
	Code string `json:"code" binding:"required"`
}

type pairingStatusResponse struct {
	InviteeToken string `json:"invitee_token,omitempty"`
	PairID       string `json:"pair_id,omitempty"`
	Status       string `json:"status"`
}

// createInviteHandler creates an invitation for the configured server URL.
func createInviteHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		var request createInviteRequest
		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
			return
		}

		invite, err := service.CreateInvite(request.ServerURL)
		if err != nil {
			status := http.StatusInternalServerError
			code := "internal_error"
			switch {
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
		})
	}
}

// redeemInviteHandler consumes the one-time code supplied by the invitee.
func redeemInviteHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		var request redeemInviteRequest
		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
			return
		}

		status, err := service.RedeemInvite(request.Code)
		if err != nil {
			code := "invalid_invite"
			httpStatus := http.StatusConflict
			if errors.Is(err, pairing.ErrExpiredInvite) {
				code, httpStatus = "expired_invite", http.StatusGone
			}
			c.JSON(httpStatus, gin.H{"error": code})
			return
		}

		c.JSON(http.StatusOK, pairingStatusResponse{
			InviteeToken: status.InviteeToken,
			PairID:       status.PairID,
			Status:       status.Status,
		})
	}
}

// pairingStatusHandler reports state to the device that created the invite.
func pairingStatusHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := strings.TrimSpace(strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer "))
		status, err := service.Status(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid_inviter_token"})
			return
		}
		c.JSON(http.StatusOK, pairingStatusResponse{PairID: status.PairID, Status: status.Status})
	}
}
