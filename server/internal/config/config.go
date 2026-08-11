package config

import "os"

// Config contains runtime settings supplied through environment variables.
type Config struct {
	Environment  string
	InstanceID   string
	InstanceName string
	Port         string
	PublicURL    string
}

// Load reads configuration and applies development-friendly defaults.
func Load() Config {
	return Config{
		Environment:  envOrDefault("PAWMATE_ENV", "development"),
		InstanceID:   envOrDefault("PAWMATE_INSTANCE_ID", "pawmate-local"),
		InstanceName: envOrDefault("PAWMATE_INSTANCE_NAME", "Our Little Home"),
		Port:         envOrDefault("PAWMATE_PORT", "8080"),
		PublicURL:    os.Getenv("PAWMATE_PUBLIC_URL"),
	}
}

func envOrDefault(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}
