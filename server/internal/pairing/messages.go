package pairing

import (
	"errors"
	"strings"
	"time"
	"unicode/utf8"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var (
	ErrInvalidMessage    = errors.New("message must contain 1 to 4000 characters and a client id")
	ErrMessageConflict   = errors.New("client id was already used for different content")
	ErrInvalidReadCursor = errors.New("read cursor does not identify a message in this home")
)

// Message is a persisted text message with a server-assigned sequence number.
type Message struct {
	ID        int64     `json:"id"`
	ClientID  string    `json:"client_id"`
	Sender    string    `json:"sender"`
	Text      string    `json:"text"`
	CreatedAt time.Time `json:"created_at"`
}

// MessagePage combines history with member-level read progress and unread count.
type MessagePage struct {
	Messages      []Message `json:"messages"`
	HasMore       bool      `json:"has_more"`
	LatestID      int64     `json:"latest_id"`
	ReadID        int64     `json:"read_id"`
	PartnerReadID int64     `json:"partner_read_id"`
	UnreadCount   int       `json:"unread_count"`
}

// chatSession requires an active paired device; the caller holds the service mutex.
func (service *Service) chatSession(token string) (Session, error) {
	session, err := service.authenticateDevice(token)
	if err != nil {
		return Session{}, err
	}
	if session.Status != "paired" {
		return Session{}, ErrNotPaired
	}
	return session, nil
}

// SendMessage stores text once per member/client id, including ambiguous retries.
func (service *Service) SendMessage(token, clientID, text string) (Message, error) {
	service.mu.Lock()
	defer service.mu.Unlock()
	session, err := service.chatSession(token)
	if err != nil {
		return Message{}, err
	}
	clientID, text = strings.TrimSpace(clientID), strings.TrimSpace(text)
	if clientID == "" || len(clientID) > 64 || !utf8.ValidString(text) || text == "" || utf8.RuneCountInString(text) > 4000 {
		return Message{}, ErrInvalidMessage
	}
	record := messageRecord{PairID: session.PairID, Sender: session.Role, ClientID: clientID,
		Text: text, CreatedAt: service.now().UnixMilli()}
	err = service.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "pair_id"}, {Name: "sender"}, {Name: "client_id"}}, DoNothing: true,
		}).Create(&record).Error; err != nil {
			return err
		}
		// Reload into a fresh model: retries must not add an implicit ID condition.
		var stored messageRecord
		if err := tx.Where("pair_id = ? AND sender = ? AND client_id = ?", session.PairID, session.Role, clientID).Take(&stored).Error; err != nil {
			return err
		}
		if stored.Text != text {
			return ErrMessageConflict
		}
		record = stored
		return nil
	})
	if err != nil {
		return Message{}, err
	}
	return record.message(), nil
}

// Messages returns bounded history or forward updates with coherent read metadata.
func (service *Service) Messages(token string, afterID, beforeID int64, limit int) (MessagePage, error) {
	service.mu.Lock()
	defer service.mu.Unlock()
	session, err := service.chatSession(token)
	if err != nil {
		return MessagePage{}, err
	}
	if afterID < 0 || beforeID < 0 || (afterID > 0 && beforeID > 0) || limit < 1 || limit > 100 {
		return MessagePage{}, ErrInvalidMessage
	}
	// One read transaction keeps pagination and receipts consistent across processes.
	page := MessagePage{Messages: []Message{}}
	err = service.db.Transaction(func(tx *gorm.DB) error {
		query := tx.Where("pair_id = ?", session.PairID)
		if afterID > 0 {
			query = query.Where("id > ?", afterID)
		}
		if beforeID > 0 {
			query = query.Where("id < ?", beforeID)
		}
		if afterID > 0 {
			query = query.Order("id ASC")
		} else {
			query = query.Order("id DESC")
		}
		var records []messageRecord
		if err := query.Limit(limit + 1).Find(&records).Error; err != nil {
			return err
		}
		page.HasMore = len(records) > limit
		if page.HasMore {
			records = records[:limit]
		}
		for _, record := range records {
			page.Messages = append(page.Messages, record.message())
		}
		if afterID == 0 {
			for i, j := 0, len(page.Messages)-1; i < j; i, j = i+1, j-1 {
				page.Messages[i], page.Messages[j] = page.Messages[j], page.Messages[i]
			}
		}
		if err := tx.Model(&messageRecord{}).Where("pair_id = ?", session.PairID).
			Select("COALESCE(MAX(id), 0)").Scan(&page.LatestID).Error; err != nil {
			return err
		}
		var cursors []readRecord
		if err := tx.Where("pair_id = ?", session.PairID).Find(&cursors).Error; err != nil {
			return err
		}
		for _, cursor := range cursors {
			if cursor.Role == session.Role {
				page.ReadID = cursor.MessageID
			} else if cursor.MessageID > page.PartnerReadID {
				page.PartnerReadID = cursor.MessageID
			}
		}
		var unread int64
		if err := tx.Model(&messageRecord{}).Where("pair_id = ? AND sender != ? AND id > ?", session.PairID, session.Role, page.ReadID).Count(&unread).Error; err != nil {
			return err
		}
		page.UnreadCount = int(unread)
		return nil
	})
	if err != nil {
		return MessagePage{}, err
	}
	return page, nil
}

// MarkMessagesRead advances a shared member cursor without allowing future ids.
func (service *Service) MarkMessagesRead(token string, messageID int64) (int64, error) {
	service.mu.Lock()
	defer service.mu.Unlock()
	session, err := service.chatSession(token)
	if err != nil {
		return 0, err
	}
	if messageID <= 0 {
		return 0, ErrInvalidReadCursor
	}
	var cursor readRecord
	err = service.db.Transaction(func(tx *gorm.DB) error {
		var exists int64
		if err := tx.Model(&messageRecord{}).Where("pair_id = ? AND id = ?", session.PairID, messageID).Count(&exists).Error; err != nil {
			return err
		}
		if exists != 1 {
			return ErrInvalidReadCursor
		}
		record := readRecord{PairID: session.PairID, Role: session.Role, MessageID: messageID}
		// An atomic upsert prevents an older device from moving the cursor backwards.
		if err := tx.Clauses(clause.OnConflict{
			Columns:   []clause.Column{{Name: "pair_id"}, {Name: "role"}},
			DoUpdates: clause.Assignments(map[string]any{"message_id": gorm.Expr("MAX(chat_reads.message_id, excluded.message_id)")}),
		}).Create(&record).Error; err != nil {
			return err
		}
		return tx.Where("pair_id = ? AND role = ?", session.PairID, session.Role).Take(&cursor).Error
	})
	return cursor.MessageID, err
}
