package download

import (
	"archive/zip"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	sampleRepoOwner = "trustarc"
	sampleRepoName  = "ccm-mobile-consent-test-apps"
	sampleRepoRef   = "release"
)

// Options holds everything needed to download and configure a sample app.
type Options struct {
	Platform string
	Domain   string
	Website  string
	SDKRef   string
	Token    string
}

var platformDirMap = map[string]string{
	"ios":                  "ios",
	"ios-spm":              "ios-spm",
	"android":              "android",
	"react-native":         "react",
	"react-native-baremetal": "react-baremetal",
	"flutter":              "flutter",
}

func Run(opts Options) error {
	platformDir, ok := platformDirMap[opts.Platform]
	if !ok {
		return fmt.Errorf("unknown platform: %s", opts.Platform)
	}

	extractDir := fmt.Sprintf("trustarc-sample-%s", opts.Platform)

	if _, err := os.Stat(extractDir); err == nil {
		fmt.Printf("⚠  %s already exists — updating configuration\n", extractDir)
		return configure(opts, extractDir)
	}

	archiveURL := fmt.Sprintf(
		"https://github.com/%s/%s/archive/refs/heads/%s.zip",
		sampleRepoOwner, sampleRepoName, sampleRepoRef,
	)

	zipPath := fmt.Sprintf("/tmp/trustarc-sample-%s-%d.zip", opts.Platform, os.Getpid())
	defer os.Remove(zipPath)

	fmt.Printf("→ Downloading %s sample application...\n", opts.Platform)
	if err := downloadFile(archiveURL, opts.Token, zipPath); err != nil {
		return fmt.Errorf("download failed: %w", err)
	}
	fmt.Println("✓ Downloaded")

	fmt.Println("→ Extracting...")
	if err := extractPlatformDir(zipPath, platformDir, extractDir); err != nil {
		return fmt.Errorf("extraction failed: %w", err)
	}
	fmt.Printf("✓ Extracted to: %s/\n", extractDir)

	fmt.Println("→ Configuring...")
	if err := configure(opts, extractDir); err != nil {
		return fmt.Errorf("configuration failed: %w", err)
	}

	fmt.Printf("\n✓ Sample app ready at: ./%s/\n", extractDir)
	return nil
}

func downloadFile(url, token, dest string) error {
	client := &http.Client{Timeout: 120 * time.Second}

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return err
	}
	if token != "" {
		req.Header.Set("Authorization", "token "+token)
	}

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("HTTP %d fetching %s", resp.StatusCode, url)
	}

	f, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer f.Close()

	_, err = io.Copy(f, resp.Body)
	return err
}

func extractPlatformDir(zipPath, platformDir, destDir string) error {
	r, err := zip.OpenReader(zipPath)
	if err != nil {
		return err
	}
	defer r.Close()

	// Determine the archive root folder (e.g. "ccm-mobile-consent-test-apps-release")
	var repoRoot string
	for _, f := range r.File {
		parts := strings.SplitN(f.Name, "/", 2)
		if parts[0] != "" {
			repoRoot = parts[0]
			break
		}
	}
	if repoRoot == "" {
		return fmt.Errorf("could not determine repo root in archive")
	}

	prefix := repoRoot + "/platforms/" + platformDir + "/"

	if err := os.MkdirAll(destDir, 0755); err != nil {
		return err
	}

	for _, f := range r.File {
		if !strings.HasPrefix(f.Name, prefix) {
			continue
		}
		rel := strings.TrimPrefix(f.Name, prefix)
		if rel == "" {
			continue
		}

		dest := filepath.Join(destDir, rel)

		if f.FileInfo().IsDir() {
			_ = os.MkdirAll(dest, 0755)
			continue
		}

		if err := os.MkdirAll(filepath.Dir(dest), 0755); err != nil {
			return err
		}
		if err := extractZipFile(f, dest); err != nil {
			return err
		}
	}

	return nil
}

func extractZipFile(f *zip.File, dest string) error {
	rc, err := f.Open()
	if err != nil {
		return err
	}
	defer rc.Close()

	out, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, rc)
	return err
}
