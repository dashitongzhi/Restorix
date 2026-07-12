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
