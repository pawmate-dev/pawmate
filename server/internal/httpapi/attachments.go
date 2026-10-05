package httpapi

import (
	"errors"
	"io"
	"mime"
	"net"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"pawmate/server/internal/pairing"
)

// sendAttachmentHandler rejects unauthenticated bodies before bounded multipart parsing.
func sendAttachmentHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := deviceBearerToken(c)
		session, err := service.Authenticate(token)
		if err != nil {
			deviceError(c, err)
			return
		}
		if session.Status != "paired" {
			deviceError(c, pairing.ErrNotPaired)
			return
		}
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, pairing.MaxAttachmentBytes+64*1024)
		if err = c.Request.ParseMultipartForm(1024 * 1024); err != nil {
			if c.Request.MultipartForm != nil {
				defer c.Request.MultipartForm.RemoveAll()
			}
			var maxErr *http.MaxBytesError
			var networkErr net.Error
			if errors.As(err, &maxErr) {
				c.JSON(http.StatusRequestEntityTooLarge, gin.H{"error": "attachment_too_large"})
			} else if errors.As(err, &networkErr) && networkErr.Timeout() {
				c.Header("Connection", "close")
				c.JSON(http.StatusRequestTimeout, gin.H{"error": "upload_timeout"})
			} else {
				c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_attachment"})
			}
			return
		}
		defer c.Request.MultipartForm.RemoveAll()
		files := c.Request.MultipartForm.File["file"]
		if len(files) != 1 || len(c.Request.MultipartForm.File) != 1 {
			chatError(c, pairing.ErrInvalidAttachment)
			return
		}
		file, err := files[0].Open()
		if err != nil {
			chatError(c, pairing.ErrInvalidAttachment)
			return
		}
		defer file.Close()
		data, err := io.ReadAll(io.LimitReader(file, pairing.MaxAttachmentBytes+1))
		if len(data) > pairing.MaxAttachmentBytes {
			c.JSON(http.StatusRequestEntityTooLarge, gin.H{"error": "attachment_too_large"})
			return
		}
		if err != nil {
			chatError(c, pairing.ErrInvalidAttachment)
			return
		}
		message, err := service.SendAttachment(token, c.PostForm("client_id"), c.PostForm("kind"), files[0].Filename, data)
		if err != nil {
			chatError(c, err)
			return
		}
		c.JSON(http.StatusOK, message)
	}
}

// downloadAttachmentHandler never exposes anonymous URLs, active content or executable paths.
func downloadAttachmentHandler(service *pairing.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil || id <= 0 {
			chatError(c, pairing.ErrInvalidAttachment)
			return
		}
		metadata, data, err := service.AttachmentData(deviceBearerToken(c), id)
		if err != nil {
			chatError(c, err)
			return
		}
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("Content-Disposition", mime.FormatMediaType("attachment", map[string]string{"filename": metadata.Name}))
		c.Header("Content-Security-Policy", "default-src 'none'; sandbox")
		c.Data(http.StatusOK, metadata.ContentType, data)
	}
}
