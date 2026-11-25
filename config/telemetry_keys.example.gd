extends RefCounted
## Telemetry keys (M6g). Copy this file to `telemetry_keys.gd` in the same
## folder and fill it in; that copy is gitignored and goes into exports.
## Both keys are client keys (they can only send data), but keep them out of git.
## Empty = that service stays off.

## Sentry: Project Settings > Client Keys (DSN).
const SENTRY_DSN := ""
## PostHog: Project settings > Project API key (starts with "phc_").
const POSTHOG_KEY := ""
## PostHog cloud region: https://us.i.posthog.com or https://eu.i.posthog.com
const POSTHOG_HOST := "https://us.i.posthog.com"
