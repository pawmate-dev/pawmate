package pairing

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"strings"
	"unicode"
	"unicode/utf8"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// MaxAttachmentBytes bounds both upload bodies and stored attachment payloads.
const MaxAttachmentBytes = 20 * 1024 * 1024

var ErrInvalidAttachment = errors.New("invalid attachment")
var ErrAttachmentNotFound = errors.New("attachment not found")

// Attachment is safe content metadata; payloads require a separate authenticated request.
type Attachment struct {
	MessageID   int64  `json:"message_id"`
	Kind        string `json:"kind"`
	Name        string `json:"name"`
	ContentType string `json:"content_type"`
	Size        int    `json:"size"`
	SHA256      string `json:"sha256"`
}

// attachmentRecord keeps binary payloads out of history pagination and SQL logs.
type attachmentRecord struct {
	MessageID   int64 `gorm:"primaryKey;autoIncrement:false"`
	Kind        string
	Name        string
	ContentType string
	Size        int
	SHA256      string
	Data        []byte
}

func (attachmentRecord) TableName() string { return "chat_attachments" }

func (record attachmentRecord) metadata() *Attachment {
	return &Attachment{MessageID: record.MessageID, Kind: record.Kind, Name: record.Name,
		ContentType: record.ContentType, Size: record.Size, SHA256: record.SHA256}
}

// SendAttachment commits bytes and the ordered message together with idempotent retries.
// File contents are never interpreted as HTML; image dimensions are bounded before decoding.
func (service *Service) SendAttachment(token, clientID, kind, name string, data []byte) (Message, error) {
	service.mu.Lock()
	defer service.mu.Unlock()
	session, err := service.chatSession(token)
	if err != nil {
		return Message{}, err
	}
	clientID = strings.TrimSpace(clientID)
	name = strings.TrimSpace(name)
	if clientID == "" || len(clientID) > 64 || len(data) == 0 || len(data) > MaxAttachmentBytes ||
		!utf8.ValidString(name) || name == "" || len(name) > 255 || strings.ContainsAny(name, "/\\") ||
		name == "." || name == ".." || strings.IndexFunc(name, unicode.IsControl) >= 0 ||
		(kind != "file" && kind != "image") {
		return Message{}, ErrInvalidAttachment
	}
	contentType := "application/octet-stream"
	if kind == "image" {
		cfg, format, err := image.DecodeConfig(bytes.NewReader(data))
		if err != nil || cfg.Width <= 0 || cfg.Height <= 0 || int64(cfg.Width)*int64(cfg.Height) > 25_000_000 {
			return Message{}, ErrInvalidAttachment
		}
		switch format {
		case "jpeg":
			contentType = "image/jpeg"
		case "png":
			contentType = "image/png"
		case "gif":
			contentType = "image/gif"
		default:
			return Message{}, ErrInvalidAttachment
		}
		// Reject truncated images as well as spoofed MIME types and SVG active content.
		if _, _, err := image.Decode(bytes.NewReader(data)); err != nil {
			return Message{}, ErrInvalidAttachment
		}
	}
	digest := sha256.Sum256(data)
	hash := hex.EncodeToString(digest[:])
	record := messageRecord{PairID: session.PairID, Sender: session.Role, ClientID: clientID, Text: name, CreatedAt: service.now().UnixMilli()}
	attachment := attachmentRecord{Kind: kind, Name: name, ContentType: contentType, Size: len(data), SHA256: hash, Data: data}
	err = service.db.Transaction(func(tx *gorm.DB) error {
		insert := tx.Clauses(clause.OnConflict{Columns: []clause.Column{{Name: "pair_id"}, {Name: "sender"}, {Name: "client_id"}}, DoNothing: true}).Create(&record)
		if insert.Error != nil {
			return insert.Error
		}
		var stored messageRecord
		if err := tx.Where("pair_id = ? AND sender = ? AND client_id = ?", session.PairID, session.Role, clientID).Take(&stored).Error; err != nil {
			return err
		}
		var existing attachmentRecord
		err := tx.Select("message_id", "kind", "name", "content_type", "size", "sha256").Where("message_id = ?", stored.ID).Take(&existing).Error
		if err == nil {
			if existing.SHA256 != hash || existing.Kind != kind || existing.Name != name {
				return ErrMessageConflict
			}
			record = stored
			attachment = existing
			return nil
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		// A pre-existing text message must not be converted into an attachment.
		if insert.RowsAffected != 1 {
			return ErrMessageConflict
		}
		attachment.MessageID = stored.ID
		if err := tx.Create(&attachment).Error; err != nil {
			return err
		}
		record = stored
		return nil
	})
	if err != nil {
		return Message{}, err
	}
	message := record.message()
	message.Attachment = attachment.metadata()
	return message, nil
}

// AttachmentData revalidates device and pair ownership on every download.
func (service *Service) AttachmentData(token string, id int64) (*Attachment, []byte, error) {
	service.mu.Lock()
	defer service.mu.Unlock()
	session, err := service.chatSession(token)
	if err != nil {
		return nil, nil, err
	}
	var record attachmentRecord
	err = service.db.Table("chat_attachments AS a").Select("a.*").Joins("JOIN chat_messages m ON m.id = a.message_id").Where("a.message_id = ? AND m.pair_id = ?", id, session.PairID).Take(&record).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil, ErrAttachmentNotFound
	}
	if err != nil {
		return nil, nil, err
	}
	return record.metadata(), record.Data, nil
}
