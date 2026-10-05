package pairing

import (
	"bytes"
	"encoding/base64"
	"errors"
	"image"
	"image/png"
	"net/url"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func profileFixture(t *testing.T, name string) Profile {
	t.Helper()
	var buffer bytes.Buffer
	if err := png.Encode(&buffer, image.NewRGBA(image.Rect(0, 0, 16, 16))); err != nil {
		t.Fatal(err)
	}
	return Profile{Nickname: name, AvatarBase64: base64.StdEncoding.EncodeToString(buffer.Bytes())}
}

func TestProfilesSurviveRestartRecoveryAndDeviceLogin(t *testing.T) {
	path := filepath.Join(t.TempDir(), "pair.db")
	service, err := OpenService(path)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { service.Close() }()
	inviter := profileFixture(t, "  小灰 🐾  ")
	invite, err := service.CreateInviteWithProfile("https://home.example.test", "Phone", inviter)
	if err != nil {
		t.Fatal(err)
	}
	uri, _ := url.Parse(invite.URL)
	code := uri.Query().Get("code")
	if _, err := service.RedeemInviteWithProfile(code, "Tablet", Profile{}); !errors.Is(err, ErrInvalidProfile) {
		t.Fatal("invalid profile consumed invitation")
	}
	partner := profileFixture(t, "小绿")
	paired, err := service.RedeemInviteWithProfile(code, "Tablet", partner)
	if err != nil {
		t.Fatal(err)
	}
	if err := service.Close(); err != nil {
		t.Fatal(err)
	}
	service, err = OpenService(path)
	if err != nil {
		t.Fatal(err)
	}
	assertProfiles := func(token, own, other string) {
		t.Helper()
		session, err := service.SessionWithProfiles(token)
		if err != nil || session.Profile == nil || session.Partner == nil || session.Profile.Nickname != own || session.Partner.Nickname != other || session.Profile.AvatarBase64 == "" {
			t.Fatalf("profiles not restored: %+v, %v", session, err)
		}
	}
	assertProfiles(invite.InviterToken, "小灰 🐾", "小绿")
	assertProfiles(paired.InviteeToken, "小绿", "小灰 🐾")
	login, err := service.CreateDeviceLoginCode(invite.InviterToken)
	if err != nil {
		t.Fatal(err)
	}
	device, err := service.RedeemDeviceLoginCode(login.Code, "Laptop")
	if err != nil {
		t.Fatal(err)
	}
	assertProfiles(device.AccessToken, "小灰 🐾", "小绿")
	recovered, err := service.Recover(invite.RecoveryCode)
	if err != nil {
		t.Fatal(err)
	}
	assertProfiles(recovered.AccessToken, "小灰 🐾", "小绿")
	assertProfiles(paired.InviteeToken, "小绿", "小灰 🐾")
}

func TestProfileValidationAndExpiredInvitationReplacement(t *testing.T) {
	valid := profileFixture(t, "Ash")
	for _, name := range []string{"", "  ", strings.Repeat("灰", 33), "Ash\nGrey", "Ash\u0085Grey"} {
		profile := valid
		profile.Nickname = name
		if _, err := normalizeProfile(profile); !errors.Is(err, ErrInvalidProfile) {
			t.Fatalf("invalid nickname accepted: %q", name)
		}
	}
	for _, avatar := range []string{"", "not-base64", base64.StdEncoding.EncodeToString([]byte("not an image")), strings.Repeat("A", base64.StdEncoding.EncodedLen(maxAvatarBytes)+4)} {
		profile := valid
		profile.AvatarBase64 = avatar
		if _, err := normalizeProfile(profile); !errors.Is(err, ErrInvalidProfile) {
			t.Fatal("invalid avatar accepted")
		}
	}
	var buffer bytes.Buffer
	png.Encode(&buffer, image.NewRGBA(image.Rect(0, 0, 513, 1)))
	profile := valid
	profile.AvatarBase64 = base64.StdEncoding.EncodeToString(buffer.Bytes())
	if _, err := normalizeProfile(profile); !errors.Is(err, ErrInvalidProfile) {
		t.Fatal("oversized dimensions accepted")
	}
	service := NewService()
	defer service.Close()
	invite, err := service.CreateInviteWithProfile("https://home.example.test", "Phone", valid)
	if err != nil {
		t.Fatal(err)
	}
	service.now = func() time.Time { return invite.ExpiresAt.Add(time.Second) }
	replacement, err := service.CreateInviteWithProfile("https://home.example.test", "Phone", profileFixture(t, "Fern"))
	if err != nil {
		t.Fatal(err)
	}
	session, err := service.SessionWithProfiles(replacement.InviterToken)
	if err != nil || session.Profile.Nickname != "Fern" || session.Partner != nil {
		t.Fatal("expired invitation retained old identity")
	}
}
