package sdk

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

const versionsURL = "https://ccm-mobile-preview.vercel.app/docs/sdk-versions.json"

type ChannelData struct {
	Latest      string   `json:"latest"`
	IOS         string   `json:"ios"`
	Android     string   `json:"android"`
	ReactNative string   `json:"reactNative"`
	Flutter     string   `json:"flutter"`
	Versions    []string `json:"versions"`
}

type SDKVersions struct {
	Release ChannelData `json:"release"`
	Stable  ChannelData `json:"stable"`
}

func FetchVersions() (*SDKVersions, error) {
	client := &http.Client{Timeout: 10 * time.Second}

	resp, err := client.Get(versionsURL)
	if err != nil {
		return nil, fmt.Errorf("fetch failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status %d from %s", resp.StatusCode, versionsURL)
	}

	var versions SDKVersions
	if err := json.NewDecoder(resp.Body).Decode(&versions); err != nil {
		return nil, fmt.Errorf("parse failed: %w", err)
	}

	return &versions, nil
}
