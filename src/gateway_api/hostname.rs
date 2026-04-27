// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Shane Utt

//! Shared hostname matching for Gateway API route attachment.

// -----------------------------------------------------------------------------
// Hostname Matching
// -----------------------------------------------------------------------------

/// Checks if a route hostname matches a listener hostname.
///
/// Wildcard matching per Gateway API spec: `*.example.com` matches
/// `foo.example.com` but not `foo.bar.example.com` (single level only).
/// Matching is bidirectional: a wildcard on either side is accepted.
pub(crate) fn hostname_matches(route_host: &str, listener_host: &str) -> bool {
    if route_host == listener_host {
        return true;
    }
    if let Some(domain) = listener_host.strip_prefix("*.")
        && let Some(subdomain) = route_host.strip_suffix(domain).and_then(|s| s.strip_suffix('.'))
        && !subdomain.is_empty()
        && !subdomain.contains('.')
    {
        return true;
    }
    if let Some(domain) = route_host.strip_prefix("*.")
        && let Some(subdomain) = listener_host.strip_suffix(domain).and_then(|s| s.strip_suffix('.'))
        && !subdomain.is_empty()
        && !subdomain.contains('.')
    {
        return true;
    }
    false
}

// -----------------------------------------------------------------------------
// Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::too_many_lines,
    clippy::cognitive_complexity,
    clippy::default_trait_access,
    clippy::match_wildcard_for_single_variants,
    clippy::missing_assert_message,
    reason = "tests"
)]
mod tests {
    use super::*;

    #[test]
    fn test_hostname_matches_exact() {
        assert!(
            hostname_matches("example.com", "example.com"),
            "exact match should succeed"
        );
    }

    #[test]
    fn test_hostname_matches_wildcard_listener() {
        assert!(
            hostname_matches("foo.example.com", "*.example.com"),
            "subdomain should match wildcard listener"
        );
        assert!(
            !hostname_matches("notexample.com", "*.example.com"),
            "non-subdomain should not match wildcard listener"
        );
    }

    #[test]
    fn test_hostname_matches_wildcard_route() {
        assert!(
            hostname_matches("*.example.com", "foo.example.com"),
            "wildcard route should match subdomain listener"
        );
    }

    #[test]
    fn test_hostname_matches_no_match() {
        assert!(
            !hostname_matches("other.com", "example.com"),
            "different hostnames should not match"
        );
    }

    #[test]
    fn test_hostname_matches_bare_domain_does_not_match_wildcard() {
        assert!(
            !hostname_matches("example.com", "*.example.com"),
            "bare domain should NOT match wildcard per Gateway API spec"
        );
    }

    #[test]
    fn test_hostname_matches_multi_level_subdomain_rejected() {
        assert!(
            !hostname_matches("foo.bar.example.com", "*.example.com"),
            "multi-level subdomain should NOT match single-level wildcard"
        );
    }
}
