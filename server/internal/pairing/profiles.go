package pairing

import (
	"bytes"
	"encoding/base64"
	"errors"
	"image"
	_ "image/jpeg"
	"image/png"
	"strings"
	"unicode"
	"unicode/utf8"
)

var ErrInvalidProfile = errors.New("nickname or avatar is invalid")

const maxAvatarBytes = 256 * 1024

// Profile is a member's shared identity, independent of devices and credentials.
type Profile struct {
	Nickname     string `json:"nickname"`
	AvatarBase64 string `json:"avatar_base64"`
}

// profileRecord stores the two members without altering legacy pairing columns.
type profileRecord struct {
	Role         string `gorm:"primaryKey"`
	Nickname     string
	AvatarBase64 string
}

// TableName identifies the additive member-identity table.
func (profileRecord) TableName() string { return "member_profiles" }

// normalizeProfile validates bounded images and strips metadata before storage.
func normalizeProfile(profile Profile) (Profile, error) {
	profile.Nickname = strings.TrimSpace(profile.Nickname)
	if !utf8.ValidString(profile.Nickname) || utf8.RuneCountInString(profile.Nickname) < 1 || utf8.RuneCountInString(profile.Nickname) > 32 || strings.ContainsFunc(profile.Nickname, unicode.IsControl) {
		return Profile{}, ErrInvalidProfile
	}
	if len(profile.AvatarBase64) > base64.StdEncoding.EncodedLen(maxAvatarBytes) {
		return Profile{}, ErrInvalidProfile
	}
	data, err := base64.StdEncoding.Strict().DecodeString(profile.AvatarBase64)
	if err != nil || len(data) == 0 || len(data) > maxAvatarBytes {
		return Profile{}, ErrInvalidProfile
	}
	config, format, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil || (format != "png" && format != "jpeg") || config.Width < 1 || config.Height < 1 || config.Width > 512 || config.Height > 512 {
		return Profile{}, ErrInvalidProfile
	}
	avatar, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return Profile{}, ErrInvalidProfile
	}
	var encoded bytes.Buffer
	if err := png.Encode(&encoded, avatar); err != nil || encoded.Len() > maxAvatarBytes {
		return Profile{}, ErrInvalidProfile
	}
	profile.AvatarBase64 = base64.StdEncoding.EncodeToString(encoded.Bytes())
	return profile, nil
}

// SessionWithProfiles returns shared profiles only to an authenticated device.
func (service *Service) SessionWithProfiles(token string) (Session, error) {
	service.mu.Lock()
	defer service.mu.Unlock()
	session, err := service.authenticateDevice(token)
	if err != nil {
		return Session{}, err
	}
	var records []profileRecord
	if err := service.db.Find(&records).Error; err != nil {
		return Session{}, err
	}
	for _, record := range records {
		profile := &Profile{Nickname: record.Nickname, AvatarBase64: record.AvatarBase64}
		if record.Role == session.Role {
			session.Profile = profile
		} else if session.Status == "paired" {
			session.Partner = profile
		}
	}
	return session, nil
}
