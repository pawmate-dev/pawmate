package httpapi

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"pawmate/server/internal/pairing"
)

// chatError returns a safe error code without logging message text or credentials.
func chatError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, pairing.ErrInvalidAttachment):
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_attachment"})
	case errors.Is(err, pairing.ErrAttachmentNotFound):
		c.JSON(http.StatusNotFound, gin.H{"error": "attachment_not_found"})
	case errors.Is(err, pairing.ErrInvalidMessage):
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_message"})
	case errors.Is(err, pairing.ErrInvalidReadCursor):
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_read_cursor"})
	case errors.Is(err, pairing.ErrMessageConflict):
		c.JSON(http.StatusConflict, gin.H{"error": "message_id_conflict"})
	default:
		deviceError(c, err)
	}
}

// chatMessagesHandler serves recent history, older pages, or incremental updates.
func chatMessagesHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		after, err1 := strconv.ParseInt(c.DefaultQuery("after_id", "0"), 10, 64)
		before, err2 := strconv.ParseInt(c.DefaultQuery("before_id", "0"), 10, 64)
		limit, err3 := strconv.Atoi(c.DefaultQuery("limit", "50"))
		if err1 != nil || err2 != nil || err3 != nil || after < 0 || before < 0 || (after > 0 && before > 0) || limit < 1 || limit > 100 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_pagination"})
			return
		}
		page, err := service.Messages(deviceBearerToken(c), after, before, limit)
		if err != nil {
			chatError(c, err)
			return
		}
		c.JSON(http.StatusOK, page)
	}
}

// sendChatMessageHandler assigns identity from the device token, never the body.
func sendChatMessageHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 32*1024)
		var request struct {
			ClientID string `json:"client_id" binding:"required,max=64"`
			Text     string `json:"text" binding:"required,max=4000"`
		}
		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_message"})
			return
		}
		message, err := service.SendMessage(deviceBearerToken(c), request.ClientID, request.Text)
		if err != nil {
			chatError(c, err)
			return
		}
		c.JSON(http.StatusOK, message)
	}
}

// readChatMessagesHandler records a monotonic member-wide read receipt.
func readChatMessagesHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		var request struct {
			MessageID int64 `json:"message_id" binding:"required,gt=0"`
		}
		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_read_cursor"})
			return
		}
		readID, err := service.MarkMessagesRead(deviceBearerToken(c), request.MessageID)
		if err != nil {
			chatError(c, err)
			return
		}
		c.JSON(http.StatusOK, gin.H{"read_id": readID})
	}
}
