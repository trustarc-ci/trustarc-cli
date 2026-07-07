package download

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

func configure(opts Options, appDir string) error {
	switch opts.Platform {
	case "ios", "ios-spm":
		return configureIOS(opts, appDir)
	case "android":
		return configureAndroid(opts, appDir)
	case "react-native", "react-native-baremetal":
		return configureReactNative(opts, appDir)
	case "flutter":
		return configureFlutter(opts, appDir)
	}
	return nil
}

// replaceInFile reads, transforms, and writes a file.
func replaceInFile(path string, transform func(string) string) error {
	content, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return os.WriteFile(path, []byte(transform(string(content))), 0644)
}

// reReplace applies a regexp substitution using a match→string function.
func reReplace(s, pattern string, fn func(groups []string) string) string {
	re := regexp.MustCompile(pattern)
	return re.ReplaceAllStringFunc(s, func(match string) string {
		return fn(re.FindStringSubmatch(match))
	})
}

func configureIOS(opts Options, appDir string) error {
	if p := findFile(appDir, "AppConfig.swift"); p != "" {
		if err := replaceInFile(p, func(s string) string {
			s = reReplace(s, `(let macDomain: String = ")([^"]*)(")`, func(g []string) string {
				return g[1] + opts.Domain + g[3]
			})
			s = reReplace(s, `(let testWebsiteUrl: String = ")([^"]*)(")`, func(g []string) string {
				return g[1] + opts.Website + g[3]
			})
			return s
		}); err != nil {
			return err
		}
		fmt.Println("  ✓ AppConfig.swift")
	}

	if p := findFileMaxDepth(appDir, "Podfile", 2); p != "" {
		if err := replaceInFile(p, func(s string) string {
			if opts.Token != "" {
				s = strings.ReplaceAll(s, "YOUR_TRUSTARC_TOKEN", opts.Token)
			}
			if opts.SDKRef != "" {
				s = reReplace(s, `(:tag\s*=>\s*['"])([^'"]*)(['"])`, func(g []string) string {
					return g[1] + opts.SDKRef + g[3]
				})
			}
			return s
		}); err != nil {
			return err
		}
		fmt.Printf("  ✓ Podfile (SDK tag: %s)\n", opts.SDKRef)
	}

	return nil
}

func configureAndroid(opts Options, appDir string) error {
	configPath := filepath.Join(appDir, "app/src/main/java/com/example/trustarcmobileapp/config/AppConfig.kt")
	if _, err := os.Stat(configPath); err == nil {
		if err := replaceInFile(configPath, func(s string) string {
			s = reReplace(s, `(const val MAC_DOMAIN: String = ")([^"]*)(")`, func(g []string) string {
				return g[1] + opts.Domain + g[3]
			})
			s = reReplace(s, `(const val TEST_WEBSITE_URL: String = ")([^"]*)(")`, func(g []string) string {
				return g[1] + opts.Website + g[3]
			})
			return s
		}); err != nil {
			return err
		}
		fmt.Println("  ✓ AppConfig.kt")
	}

	settingsPath := filepath.Join(appDir, "settings.gradle")
	if _, err := os.Stat(settingsPath); err == nil && opts.Token != "" {
		if err := replaceInFile(settingsPath, func(s string) string {
			return strings.ReplaceAll(s, "YOUR_TRUSTARC_TOKEN", opts.Token)
		}); err != nil {
			return err
		}
		fmt.Println("  ✓ settings.gradle")
	}

	tomlPath := filepath.Join(appDir, "gradle/libs.versions.toml")
	if _, err := os.Stat(tomlPath); err == nil && opts.SDKRef != "" {
		if err := replaceInFile(tomlPath, func(s string) string {
			return reReplace(s, `(?m)^(\s*trustarcConsentSdk\s*=\s*)"[^"]*"`, func(g []string) string {
				return g[1] + `"` + opts.SDKRef + `"`
			})
		}); err != nil {
			return err
		}
		fmt.Printf("  ✓ libs.versions.toml (SDK: %s)\n", opts.SDKRef)
	}

	return nil
}

func configureReactNative(opts Options, appDir string) error {
	configPath := filepath.Join(appDir, "config/app.config.ts")
	if _, err := os.Stat(configPath); err == nil {
		if err := replaceInFile(configPath, func(s string) string {
			s = reReplace(s, `(macDomain:\s*")([^"]*)(")`, func(g []string) string {
				return g[1] + opts.Domain + g[3]
			})
			s = reReplace(s, `(testWebsiteUrl:\s*")([^"]*)(")`, func(g []string) string {
				return g[1] + opts.Website + g[3]
			})
			return s
		}); err != nil {
			return err
		}
		fmt.Println("  ✓ app.config.ts")
	}

	appJSONPath := filepath.Join(appDir, "app.json")
	if _, err := os.Stat(appJSONPath); err == nil && opts.Token != "" {
		if err := replaceInFile(appJSONPath, func(s string) string {
			return strings.ReplaceAll(s, "YOUR_TRUSTARC_TOKEN", opts.Token)
		}); err != nil {
			return err
		}
		fmt.Println("  ✓ app.json")
	}

	pkgPath := filepath.Join(appDir, "package.json")
	if _, err := os.Stat(pkgPath); err == nil && opts.SDKRef != "" {
		if err := replaceInFile(pkgPath, func(s string) string {
			return reReplace(s,
				`("@trustarc/trustarc-react-native-consent-sdk"\s*:\s*")([^"]*)(")`,
				func(g []string) string {
					return g[1] + opts.SDKRef + g[3]
				})
		}); err != nil {
			return err
		}
		fmt.Printf("  ✓ package.json (SDK: %s)\n", opts.SDKRef)
	}

	return nil
}

func configureFlutter(opts Options, appDir string) error {
	envPath := filepath.Join(appDir, ".env")
	if _, err := os.Stat(envPath); err == nil {
		if err := replaceInFile(envPath, func(s string) string {
			s = reReplace(s, `(?m)^(MAC_DOMAIN=).*`, func(g []string) string {
				return g[1] + opts.Domain
			})
			s = reReplace(s, `(?m)^(TEST_WEBSITE_URL=).*`, func(g []string) string {
				return g[1] + opts.Website
			})
			return s
		}); err != nil {
			return err
		}
		fmt.Println("  ✓ .env")
	}

	mainPath := filepath.Join(appDir, "lib/main.dart")
	if _, err := os.Stat(mainPath); err == nil {
		if err := replaceInFile(mainPath, func(s string) string {
			return reReplace(s, `(const String kDefaultDomainName = ")([^"]*)(")`, func(g []string) string {
				return g[1] + opts.Domain + g[3]
			})
		}); err != nil {
			return err
		}
		fmt.Println("  ✓ main.dart")
	}

	pubspecPath := filepath.Join(appDir, "pubspec.yaml")
	if _, err := os.Stat(pubspecPath); err == nil {
		if err := replaceInFile(pubspecPath, func(s string) string {
			if opts.Token != "" {
				s = strings.ReplaceAll(s, "YOUR_TRUSTARC_TOKEN", opts.Token)
			}
			if opts.SDKRef != "" {
				s = reReplace(s, `(?m)^(\s*ref:\s*).*`, func(g []string) string {
					return g[1] + opts.SDKRef
				})
			}
			return s
		}); err != nil {
			return err
		}
		fmt.Printf("  ✓ pubspec.yaml (ref: %s)\n", opts.SDKRef)
	}

	return nil
}

func findFile(dir, name string) string {
	var found string
	_ = filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		if info.Name() == name {
			found = path
			return filepath.SkipAll
		}
		return nil
	})
	return found
}

func findFileMaxDepth(root, name string, maxDepth int) string {
	var found string
	clean := filepath.Clean(root)
	_ = filepath.Walk(clean, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		rel, _ := filepath.Rel(clean, path)
		depth := len(strings.Split(rel, string(filepath.Separator)))
		if info.IsDir() && depth > maxDepth {
			return filepath.SkipDir
		}
		if !info.IsDir() && info.Name() == name {
			found = path
			return filepath.SkipAll
		}
		return nil
	})
	return found
}
