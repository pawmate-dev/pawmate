package pairing

import (
	"bytes"
	"errors"
	"image"
	"image/png"
	"path/filepath"
	"testing"
)

func TestAttachmentPersistenceIdempotencyAndReceipts(t *testing.T) {
	path := filepath.Join(t.TempDir(), "attachments.db")
	service, err := OpenService(path)
	if err != nil {
		t.Fatal(err)
	}
	invite, partner := pairedDevices(t, service)
	data := []byte("private file bytes")
	first, err := service.SendAttachment(invite.InviterToken, "file-1", "file", "笔记.txt", data)
	if err != nil || first.Attachment == nil || first.Attachment.MessageID != first.ID {
		t.Fatal("attachment not atomic", err)
	}
	retry, err := service.SendAttachment(invite.InviterToken, "file-1", "file", "笔记.txt", data)
	if err != nil || retry.ID != first.ID {
		t.Fatal("retry duplicated message", err)
	}
	if _, err := service.SendAttachment(invite.InviterToken, "file-1", "file", "different.txt", data); !errors.Is(err, ErrMessageConflict) {
		t.Fatal("changed filename accepted", err)
	}
	if _, err := service.SendMessage(invite.InviterToken, "file-1", "笔记.txt"); !errors.Is(err, ErrMessageConflict) {
		t.Fatal("attachment converted to text", err)
	}
	text, _ := service.SendMessage(invite.InviterToken, "text", "hello")
	if _, err := service.SendAttachment(invite.InviterToken, "text", "file", "hello", data); !errors.Is(err, ErrMessageConflict) {
		t.Fatal("text converted to attachment", err, text)
	}
	var encoded bytes.Buffer
	if err := png.Encode(&encoded, image.NewRGBA(image.Rect(0, 0, 2, 2))); err != nil {
		t.Fatal(err)
	}
	picture, err := service.SendAttachment(partner.InviteeToken, "photo-1", "image", "picture.png", encoded.Bytes())
	if err != nil || picture.Attachment.ContentType != "image/png" {
		t.Fatal("image rejected", err)
	}
	page, err := service.Messages(partner.InviteeToken, 0, 0, 50)
	if err != nil || page.UnreadCount != 2 || len(page.Messages) != 3 || page.Messages[0].Attachment == nil {
		t.Fatal("history lost attachment metadata", err, page)
	}
	if _, err := service.MarkMessagesRead(partner.InviteeToken, first.ID); err != nil {
		t.Fatal(err)
	}
	service.Close()
	service, err = OpenService(path)
	if err != nil {
		t.Fatal(err)
	}
	defer service.Close()
	metadata, payload, err := service.AttachmentData(partner.InviteeToken, first.ID)
	if err != nil || metadata.Name != "笔记.txt" || !bytes.Equal(payload, data) {
		t.Fatal("restart lost private attachment", err)
	}
	if _, _, err := service.AttachmentData("bad-token", first.ID); !errors.Is(err, ErrInvalidSessionToken) {
		t.Fatal("anonymous download allowed", err)
	}
	if _, _, err := service.AttachmentData(partner.InviteeToken, 999); !errors.Is(err, ErrAttachmentNotFound) {
		t.Fatal("missing attachment not hidden", err)
	}
}

func TestAttachmentValidationCreatesNoMessages(t *testing.T) {
	service := NewService()
	defer service.Close()
	invite, _ := pairedDevices(t, service)
	for _, sample := range []struct {
		kind, name string
		data       []byte
	}{
		{"file", "../private", []byte("x")}, {"file", "bad\nname", []byte("x")}, {"file", "empty", nil},
		{"file", "large", bytes.Repeat([]byte("x"), MaxAttachmentBytes+1)},
		{"image", "fake.png", []byte("<svg onload='alert(1)'/>")},
	} {
		if _, err := service.SendAttachment(invite.InviterToken, "invalid", sample.kind, sample.name, sample.data); !errors.Is(err, ErrInvalidAttachment) {
			t.Fatal("invalid content accepted", err)
		}
	}
	page, _ := service.Messages(invite.InviterToken, 0, 0, 50)
	if len(page.Messages) != 0 {
		t.Fatal("invalid uploads left messages")
	}
}
