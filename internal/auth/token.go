package auth

import (
	"fmt"
	"net/http"
	"strings"
	"time"
)

// ValidateToken checks that the token can access trustarc/trustarc-mobile-consent.
func ValidateToken(token string) error {
	client := &http.Client{Timeout: 10 * time.Second}

	req, err := http.NewRequest("GET", "https://api.github.com/repos/trustarc/trustarc-mobile-consent", nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "token "+strings.TrimSpace(token))
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("connection failed: %w", err)
	}
	defer resp.Body.Close()

	switch resp.StatusCode {
	case 200:
		return nil
	case 401:
		return fmt.Errorf("invalid token (401 Unauthorized)")
	case 403:
		return fmt.Errorf("token lacks access to trustarc/trustarc-mobile-consent (403 Forbidden)")
	case 404:
		return fmt.Errorf("repository not found or token lacks access (404)")
	default:
		return fmt.Errorf("unexpected status: %d", resp.StatusCode)
	}
}
