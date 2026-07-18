use std::process::Command;

#[test]
fn scan_returns_nonzero_when_required_dependencies_are_unavailable() {
    let config_path = std::env::temp_dir().join(format!(
        "restorix-scan-exit-test-{}-{}.json",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));

    let output = Command::new(env!("CARGO_BIN_EXE_restorix"))
        .args(["scan", "--json"])
        .env("PATH", "/usr/bin:/bin:/usr/sbin:/sbin")
        .env("RESTORIX_CONFIG", &config_path)
        .output()
        .unwrap();

    assert!(!output.status.success());

    let scan: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert!(scan["errors"]
        .as_array()
        .is_some_and(|errors| !errors.is_empty()));
    assert!(scan["summary"]["error_count"]
        .as_u64()
        .is_some_and(|count| count > 0));
    assert!(scan["errors"]
        .as_array()
        .is_some_and(|errors| errors.iter().all(|error| error["code"].is_string())));
}

#[test]
fn markdown_report_returns_nonzero_when_scan_has_hard_errors() {
    let config_path = std::env::temp_dir().join(format!(
        "restorix-report-exit-test-{}-{}.json",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));

    let output = Command::new(env!("CARGO_BIN_EXE_restorix"))
        .args(["report", "markdown", "--language", "en"])
        .env("PATH", "/usr/bin:/bin:/usr/sbin:/sbin")
        .env("RESTORIX_CONFIG", &config_path)
        .output()
        .unwrap();

    assert!(!output.status.success());
    assert!(String::from_utf8(output.stdout)
        .unwrap()
        .contains("## Errors"));
}

#[test]
fn config_commit_accepts_one_typed_settings_payload() {
    let config_path = std::env::temp_dir().join(format!(
        "restorix-config-commit-test-{}-{}.json",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let payload = serde_json::json!({
        "stale_hours": 48,
        "loose_matching": true,
        "show_dock_icon": false,
        "launch_at_login": true,
        "notifications_enabled": true,
        "cli_path": "/opt/restorix"
    })
    .to_string();

    let output = Command::new(env!("CARGO_BIN_EXE_restorix"))
        .args(["config", "commit", &payload])
        .env("RESTORIX_CONFIG", &config_path)
        .output()
        .unwrap();

    assert!(output.status.success());
    let config: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(config["stale_hours"], 48);
    assert_eq!(config["loose_matching"], true);
    assert_eq!(config["show_dock_icon"], false);
    assert_eq!(config["launch_at_login"], true);
    assert_eq!(config["notifications_enabled"], true);
    assert_eq!(config["cli_path"], "/opt/restorix");

    let _ = std::fs::remove_file(config_path);
}

#[test]
fn legacy_config_set_remains_a_compatibility_adapter() {
    let config_path = std::env::temp_dir().join(format!(
        "restorix-config-set-test-{}-{}.json",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));

    let first = Command::new(env!("CARGO_BIN_EXE_restorix"))
        .args(["config", "set", "stale_hours", "48"])
        .env("RESTORIX_CONFIG", &config_path)
        .output()
        .unwrap();
    assert!(first.status.success());

    let second = Command::new(env!("CARGO_BIN_EXE_restorix"))
        .args(["config", "set", "notifications_enabled", "yes"])
        .env("RESTORIX_CONFIG", &config_path)
        .output()
        .unwrap();
    assert!(second.status.success());

    let config: serde_json::Value = serde_json::from_slice(&second.stdout).unwrap();
    assert_eq!(config["stale_hours"], 48);
    assert_eq!(config["notifications_enabled"], true);
    assert_eq!(config["show_dock_icon"], true);

    let _ = std::fs::remove_file(config_path);
}
