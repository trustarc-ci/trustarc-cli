package main

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/lipgloss"
	"github.com/trustarc-ci/trustarc-cli/internal/auth"
	"github.com/trustarc-ci/trustarc-cli/internal/download"
	"github.com/trustarc-ci/trustarc-cli/internal/sdk"
)

var (
	headerStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#FFFFFF")).
			Background(lipgloss.Color("#3B82F6")).
			Padding(0, 3)

	successStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#22C55E")).
			Bold(true)

	errStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#EF4444")).
			Bold(true)

	infoStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#60A5FA"))

	dimStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#6B7280"))
)

func main() {
	fmt.Println()
	fmt.Println(headerStyle.Render("  TrustArc Mobile Consent SDK  "))
	fmt.Println(dimStyle.Render("  Configurator · Go Edition      "))
	fmt.Println()

	token, err := handleToken()
	if err != nil {
		if errors.Is(err, huh.ErrUserAborted) {
			os.Exit(0)
		}
		fmt.Println(errStyle.Render("✗ " + err.Error()))
		os.Exit(1)
	}
	fmt.Println(successStyle.Render("✓ Token validated"))
	fmt.Println()

	for {
		var choice string
		err := huh.NewForm(
			huh.NewGroup(
				huh.NewSelect[string]().
					Title("Main Menu").
					Options(
						huh.NewOption("Download Sample Application", "download"),
						huh.NewOption("Exit", "exit"),
					).
					Value(&choice),
			),
		).Run()

		if err != nil {
			if errors.Is(err, huh.ErrUserAborted) {
				break
			}
			fmt.Println(errStyle.Render("✗ " + err.Error()))
			break
		}

		switch choice {
		case "download":
			fmt.Println()
			if err := handleDownload(token); err != nil && !errors.Is(err, huh.ErrUserAborted) {
				fmt.Println(errStyle.Render("✗ " + err.Error()))
			}
		case "exit":
			fmt.Println(infoStyle.Render("Goodbye!"))
			return
		}
		fmt.Println()
	}
}

func handleToken() (string, error) {
	existing := strings.TrimSpace(os.Getenv("TRUSTARC_TOKEN"))

	if existing != "" && len(existing) >= 8 {
		preview := existing[:4] + strings.Repeat("·", len(existing)-8) + existing[len(existing)-4:]

		var useExisting bool
		err := huh.NewForm(
			huh.NewGroup(
				huh.NewConfirm().
					Title(fmt.Sprintf("Found existing token (%s). Use it?", preview)).
					Affirmative("Yes").
					Negative("Enter a new one").
					Value(&useExisting),
			),
		).Run()
		if err != nil {
			return "", err
		}

		if useExisting {
			fmt.Print(infoStyle.Render("Validating... "))
			if err := auth.ValidateToken(existing); err != nil {
				return "", err
			}
			fmt.Println(successStyle.Render("✓"))
			return existing, nil
		}
	}

	var token string
	err := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("GitHub Personal Access Token").
				Description("Needs read access to trustarc/trustarc-mobile-consent").
				Password(true).
				Value(&token).
				Validate(func(s string) error {
					if strings.TrimSpace(s) == "" {
						return fmt.Errorf("token cannot be empty")
					}
					return nil
				}),
		),
	).Run()
	if err != nil {
		return "", err
	}

	token = strings.TrimSpace(token)
	fmt.Print(infoStyle.Render("Validating... "))
	if err := auth.ValidateToken(token); err != nil {
		return "", err
	}
	fmt.Println(successStyle.Render("✓"))

	return token, nil
}

func handleDownload(token string) error {
	var platform string
	err := huh.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Select platform").
				Options(
					huh.NewOption("iOS (CocoaPods)", "ios"),
					huh.NewOption("iOS (Swift Package Manager)", "ios-spm"),
					huh.NewOption("Android", "android"),
					huh.NewOption("React Native (Expo)", "react-native"),
					huh.NewOption("React Native (Bare Metal)", "react-native-baremetal"),
					huh.NewOption("Flutter", "flutter"),
				).
				Value(&platform),
		),
	).Run()
	if err != nil {
		return err
	}

	defaultDomain := "mac_trustarc.com"
	if d := os.Getenv("MAC_DOMAIN"); d != "" {
		defaultDomain = d
	}
	defaultWebsite := "https://trustarc.com"
	if w := os.Getenv("WEBSITE"); w != "" {
		defaultWebsite = w
	}

	var domain, website string
	err = huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("MAC Domain").
				Placeholder(defaultDomain).
				Value(&domain),
			huh.NewInput().
				Title("Website to load").
				Placeholder(defaultWebsite).
				Value(&website),
		),
	).Run()
	if err != nil {
		return err
	}
	if strings.TrimSpace(domain) == "" {
		domain = defaultDomain
	}
	if strings.TrimSpace(website) == "" {
		website = defaultWebsite
	}

	sdkRef, err := selectSDKVersion()
	if err != nil {
		return err
	}

	return download.Run(download.Options{
		Platform: platform,
		Domain:   domain,
		Website:  website,
		SDKRef:   sdkRef,
		Token:    token,
	})
}

func selectSDKVersion() (string, error) {
	var channel string
	err := huh.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Select SDK channel").
				Options(
					huh.NewOption("Release  — latest features", "release"),
					huh.NewOption("Stable   — LTS track", "stable"),
					huh.NewOption("Custom   — enter a specific ref", "custom"),
				).
				Value(&channel),
		),
	).Run()
	if err != nil {
		return "", err
	}

	if channel == "custom" {
		var ref string
		err := huh.NewForm(
			huh.NewGroup(
				huh.NewInput().
					Title("SDK ref").
					Description("A git tag, branch name, or version string").
					Placeholder("e.g. 2607.272-ios-dev").
					Value(&ref).
					Validate(func(s string) error {
						if strings.TrimSpace(s) == "" {
							return fmt.Errorf("ref cannot be empty")
						}
						return nil
					}),
			),
		).Run()
		if err != nil {
			return "", err
		}
		return strings.TrimSpace(ref), nil
	}

	// Fetch all versions for the chosen channel
	fmt.Print(infoStyle.Render("Fetching available versions... "))
	versions, err := sdk.FetchVersions()
	if err != nil {
		fmt.Println(dimStyle.Render("(offline — using channel ref directly)"))
		return channel, nil
	}
	fmt.Println(successStyle.Render("✓"))

	channelData := versions.Release
	if channel == "stable" {
		channelData = versions.Stable
	}

	options := make([]huh.Option[string], len(channelData.Versions))
	for i, v := range channelData.Versions {
		label := v
		if i == 0 {
			label = v + "  ← latest"
		}
		options[i] = huh.NewOption(label, v)
	}

	var selected string
	err = huh.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title(fmt.Sprintf("Select %s version", channel)).
				Options(options...).
				Value(&selected),
		),
	).Run()
	if err != nil {
		return "", err
	}

	// Latest version → use the floating channel tag ("release"/"stable")
	// Older version → pass the version string as the ref directly
	if selected == channelData.Latest {
		return channel, nil
	}
	return selected, nil
}
