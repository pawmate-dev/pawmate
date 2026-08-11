package httpapi

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"pawmate/server/internal/config"
)

type instanceResponse struct {
	APIVersion   string   `json:"api_version"`
	Features     []string `json:"features"`
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	PublicURL    string   `json:"public_url,omitempty"`
	Registration string   `json:"registration"`
}

func instanceHandler(cfg config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusOK, instanceResponse{
			APIVersion:   "v1",
			Features:     []string{"pairing"},
			ID:           cfg.InstanceID,
			Name:         cfg.InstanceName,
			PublicURL:    cfg.PublicURL,
			Registration: "closed",
		})
	}
}
