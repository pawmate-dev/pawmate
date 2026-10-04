package pairing

import (
	"errors"
	"fmt"
	"path/filepath"
	"sync"
	"testing"
)

func TestMessagesAndSharedReadReceiptsSurviveRestart(t *testing.T) {
	path := filepath.Join(t.TempDir(), "chat.db")
	service, err := OpenService(path)
	if err != nil {
		t.Fatal(err)
	}
	invite, partner := pairedDevices(t, service)
	first, err := service.SendMessage(invite.InviterToken, "phone-1", "你好，一起做饭吧 🐾")
	if err != nil {
		t.Fatal(err)
	}
	second, err := service.SendMessage(partner.InviteeToken, "partner-1", "好呀")
	if err != nil {
		t.Fatal(err)
	}
	page, err := service.Messages(partner.InviteeToken, 0, 0, 50)
	if err != nil || page.UnreadCount != 1 || len(page.Messages) != 2 {
		t.Fatalf("unexpected initial history: %+v, %v", page, err)
	}
	if page.Messages[0].Text != first.Text {
		t.Fatal("Unicode message changed")
	}
	code, _ := service.CreateDeviceLoginCode(partner.InviteeToken)
	tablet, err := service.RedeemDeviceLoginCode(code.Code, "Tablet")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := service.MarkMessagesRead(tablet.AccessToken, first.ID); err != nil {
		t.Fatal(err)
	}
	page, err = service.Messages(partner.InviteeToken, 0, 0, 50)
	if err != nil || page.ReadID != first.ID || page.UnreadCount != 0 {
		t.Fatal("read receipt did not synchronize across devices", err)
	}
	page, _ = service.Messages(invite.InviterToken, 0, 0, 50)
	if page.PartnerReadID != first.ID || page.UnreadCount != 1 {
		t.Fatal("partner receipt or own unread count is wrong")
	}
	if _, err := service.MarkMessagesRead(invite.InviterToken, second.ID); err != nil {
		t.Fatal(err)
	}
	if read, err := service.MarkMessagesRead(invite.InviterToken, first.ID); err != nil || read != second.ID {
		t.Fatal("read cursor regressed", err)
	}
	if _, err := service.MarkMessagesRead(invite.InviterToken, second.ID+100); !errors.Is(err, ErrInvalidReadCursor) {
		t.Fatal("future cursor accepted", err)
	}
	service.Close()
	service, err = OpenService(path)
	if err != nil {
		t.Fatal(err)
	}
	defer service.Close()
	page, err = service.Messages(invite.InviterToken, 0, 0, 50)
	if err != nil || len(page.Messages) != 2 || page.UnreadCount != 0 || page.PartnerReadID != first.ID {
		t.Fatal("restart lost messages or receipts", err)
	}
}

func TestMessageRetriesAreIdempotentAndMemberScoped(t *testing.T) {
	service := NewService()
	defer service.Close()
	invite, partner := pairedDevices(t, service)
	var wg sync.WaitGroup
	ids := make(chan int64, 4)
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			message, err := service.SendMessage(invite.InviterToken, "same-client-id", "hello")
			if err != nil {
				t.Error(err)
				return
			}
			ids <- message.ID
		}()
	}
	wg.Wait()
	close(ids)
	var firstID int64
	for id := range ids {
		if firstID == 0 {
			firstID = id
		}
		if id != firstID {
			t.Fatal("retry duplicated a message")
		}
	}
	if _, err := service.SendMessage(invite.InviterToken, "same-client-id", "different"); !errors.Is(err, ErrMessageConflict) {
		t.Fatal("client id conflict accepted", err)
	}
	if _, err := service.SendMessage(partner.InviteeToken, "same-client-id", "hello"); err != nil {
		t.Fatal("client ids incorrectly collide across members", err)
	}
	page, _ := service.Messages(partner.InviteeToken, 0, 0, 50)
	if len(page.Messages) != 2 || page.UnreadCount != 1 {
		t.Fatal("idempotency changed counts")
	}
}

func TestChatPaginationValidationAndRevokedSessions(t *testing.T) {
	service := NewService()
	defer service.Close()
	invite, _ := pairedDevices(t, service)
	for i := 0; i < 7; i++ {
		if _, err := service.SendMessage(invite.InviterToken, fmt.Sprint(i), fmt.Sprint("message ", i)); err != nil {
			t.Fatal(err)
		}
	}
	recent, err := service.Messages(invite.InviterToken, 0, 0, 3)
	if err != nil || !recent.HasMore || len(recent.Messages) != 3 {
		t.Fatal("recent pagination failed", err)
	}
	older, err := service.Messages(invite.InviterToken, 0, recent.Messages[0].ID, 3)
	if err != nil || !older.HasMore || older.Messages[2].ID >= recent.Messages[0].ID {
		t.Fatal("history pages overlap", err)
	}
	forward, err := service.Messages(invite.InviterToken, older.Messages[0].ID, 0, 3)
	if err != nil || !forward.HasMore || forward.Messages[0].ID <= older.Messages[0].ID {
		t.Fatal("forward pagination failed", err)
	}
	for _, text := range []string{"", "   "} {
		if _, err := service.SendMessage(invite.InviterToken, "empty", text); !errors.Is(err, ErrInvalidMessage) {
			t.Fatal("empty message accepted")
		}
	}
	if _, err := service.Messages(invite.InviterToken, 1, 1, 3); !errors.Is(err, ErrInvalidMessage) {
		t.Fatal("ambiguous pagination accepted")
	}
	session, _ := service.Authenticate(invite.InviterToken)
	if err := service.RevokeDevice(invite.InviterToken, session.DeviceID); err != nil {
		t.Fatal(err)
	}
	if _, err := service.SendMessage(invite.InviterToken, "revoked", "no"); !errors.Is(err, ErrInvalidSessionToken) {
		t.Fatal("revoked device can send")
	}
	if _, err := service.Messages(invite.InviterToken, 0, 0, 50); !errors.Is(err, ErrInvalidSessionToken) {
		t.Fatal("revoked device can read")
	}
	if _, err := service.MarkMessagesRead(invite.InviterToken, recent.LatestID); !errors.Is(err, ErrInvalidSessionToken) {
		t.Fatal("revoked device can acknowledge")
	}
}
