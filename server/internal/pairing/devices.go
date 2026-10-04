package pairing

import (
	"errors"
	"strings"
	"time"

	"gorm.io/gorm"
)

var (
	ErrInvalidDeviceCode = errors.New("device login code is invalid or expired")
	ErrDeviceNotFound    = errors.New("device does not belong to this member")
)

// Device describes one independently authenticated installation, without its token.
type Device struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
	Current   bool      `json:"current"`
}

// DeviceLoginCode grants one additional device access to the issuing member.
type DeviceLoginCode struct {
	Code      string    `json:"code"`
	ExpiresAt time.Time `json:"expires_at"`
}

// DeviceCredentials is issued once when a new device redeems a login code.
type DeviceCredentials struct {
	AccessToken string `json:"access_token"`
	PairID      string `json:"pair_id"`
	Role        string `json:"role"`
}

// migrateDevices atomically imports legacy tokens once, preserving existing logins.
func (service *Service) migrateDevices() error {
	return service.db.Transaction(func(tx *gorm.DB) error {
		var migrated int64
		if err := tx.Model(&deviceMigration{}).Where("version = ?", 1).Count(&migrated).Error; err != nil {
			return err
		}
		if migrated != 0 {
			return nil
		}
		var state pairingRecord
		err := tx.Take(&state, "id = ?", 1).Error
		if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		for role, hash := range map[string][]byte{"inviter": state.InviterTokenHash, "invitee": state.InviteeTokenHash} {
			if len(hash) == 0 {
				continue
			}
			record := deviceRecord{ID: "legacy-" + role, Role: role, TokenHash: hash,
				Name: "Existing device", CreatedAt: service.now().Unix()}
			if err := tx.Create(&record).Error; err != nil {
				return err
			}
		}
		// A durable marker prevents revoked legacy tokens being re-imported on restart.
		return tx.Create(&deviceMigration{Version: 1}).Error
	})
}

// deviceName bounds the optional display name; it is never used as identity.
func deviceName(names []string) string {
	if len(names) == 0 || strings.TrimSpace(names[0]) == "" {
		return "Pawmate device"
	}
	runes := []rune(strings.TrimSpace(names[0]))
	if len(runes) > 80 {
		runes = runes[:80]
	}
	return string(runes)
}

// insertDevice records a unique token hash in the caller's transaction.
func (service *Service) insertDevice(tx *gorm.DB, role, token, name string) (string, error) {
	id, err := randomToken(16)
	if err != nil {
		return "", err
	}
	hash := tokenHash(token)
	err = tx.Create(&deviceRecord{ID: id, Role: role, TokenHash: hash[:], Name: name, CreatedAt: service.now().Unix()}).Error
	return id, err
}

// CreateDeviceLoginCode issues a ten-minute code from an already paired device.
func (service *Service) CreateDeviceLoginCode(accessToken string) (DeviceLoginCode, error) {
	service.mu.Lock()
	defer service.mu.Unlock()
	session, err := service.authenticateDevice(accessToken)
	if err != nil {
		return DeviceLoginCode{}, err
	}
	if session.Status != "paired" {
		return DeviceLoginCode{}, ErrNotPaired
	}
	code, err := randomToken(24)
	if err != nil {
		return DeviceLoginCode{}, err
	}
	expiresAt := service.now().Add(inviteTTL)
	hash := tokenHash(code)
	err = service.db.Transaction(func(tx *gorm.DB) error {
		// Each device has at most one outstanding login code.
		if err := tx.Where("issuer_id = ? OR expires_at <= ?", session.DeviceID, service.now().Unix()).Delete(&deviceCodeRecord{}).Error; err != nil {
			return err
		}
		return tx.Create(&deviceCodeRecord{CodeHash: hash[:], Role: session.Role,
			IssuerID: session.DeviceID, ExpiresAt: expiresAt.Unix()}).Error
	})
	if err != nil {
		return DeviceLoginCode{}, err
	}
	return DeviceLoginCode{Code: code, ExpiresAt: expiresAt}, nil
}

// RedeemDeviceLoginCode consumes a code and adds a session without revoking others.
func (service *Service) RedeemDeviceLoginCode(code, name string) (DeviceCredentials, error) {
	service.mu.Lock()
	defer service.mu.Unlock()
	hash := tokenHash(strings.TrimSpace(code))
	var credentials DeviceCredentials
	err := service.db.Transaction(func(tx *gorm.DB) error {
		var record struct {
			Role   string
			PairID string
		}
		err := tx.Table("device_login_codes AS c").Select("c.role, p.pair_id").
			Joins("JOIN pairing_state AS p ON p.id = 1 AND p.paired = 1").
			Where("c.code_hash = ? AND c.expires_at > ?", hash[:], service.now().Unix()).Take(&record).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrInvalidDeviceCode
		}
		if err != nil {
			return err
		}
		result := tx.Where("code_hash = ? AND expires_at > ?", hash[:], service.now().Unix()).Delete(&deviceCodeRecord{})
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected != 1 {
			return ErrInvalidDeviceCode
		}
		token, err := randomToken(32)
		if err != nil {
			return err
		}
		if _, err := service.insertDevice(tx, record.Role, token, deviceName([]string{name})); err != nil {
			return err
		}
		credentials = DeviceCredentials{AccessToken: token, PairID: record.PairID, Role: record.Role}
		return nil
	})
	if err != nil {
		return DeviceCredentials{}, err
	}
	return credentials, nil
}

// Devices lists only the authenticated member's installations.
func (service *Service) Devices(accessToken string) ([]Device, error) {
	service.mu.Lock()
	defer service.mu.Unlock()
	session, err := service.authenticateDevice(accessToken)
	if err != nil {
		return nil, err
	}
	var records []deviceRecord
	if err := service.db.Where("role = ?", session.Role).Order("created_at, id").Find(&records).Error; err != nil {
		return nil, err
	}
	devices := []Device{}
	for _, record := range records {
		devices = append(devices, Device{ID: record.ID, Name: record.Name,
			CreatedAt: time.Unix(record.CreatedAt, 0).UTC(), Current: record.ID == session.DeviceID})
	}
	return devices, nil
}

// RevokeDevice removes one of this member's sessions and its outstanding codes.
func (service *Service) RevokeDevice(accessToken, deviceID string) error {
	service.mu.Lock()
	defer service.mu.Unlock()
	session, err := service.authenticateDevice(accessToken)
	if err != nil {
		return err
	}
	result := service.db.Where("id = ? AND role = ?", deviceID, session.Role).Delete(&deviceRecord{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected != 1 {
		return ErrDeviceNotFound
	}
	return nil
}
