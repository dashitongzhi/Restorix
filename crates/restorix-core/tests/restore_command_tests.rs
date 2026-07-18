use restorix_core::scanner::restore_command::build_restore_command;

mod support;
use support::*;

#[test]
fn restore_command_quotes_untrusted_values_and_maps_password_environment() {
    let mut repository = repo();
    repository.location = "s3:bucket/$(printf injected) 'quoted'".to_string();
    repository.password_env_key = Some("RESTIC_BACKUP_PASSWORD".to_string());

    let command = build_restore_command(
        &repository,
        "snapshot; printf injected",
        "/data/`printf injected`/volume",
    );

    assert_eq!(
        command,
        "RESTIC_REPOSITORY='s3:bucket/$(printf injected) '\"'\"'quoted'\"'\"'' RESTIC_PASSWORD=\"${RESTIC_BACKUP_PASSWORD:?Set RESTIC_BACKUP_PASSWORD before running this command}\" restic restore 'snapshot; printf injected' --target './restorix-restore-test' --include '/data/`printf injected`/volume'"
    );
}

#[test]
fn restore_command_ignores_invalid_password_environment_names() {
    let mut repository = repo();
    repository.password_env_key = Some("RESTIC_PASSWORD; printf injected".to_string());

    let command = build_restore_command(&repository, "snapshot", "/data/volume");

    assert!(!command.contains("RESTIC_PASSWORD=\"${RESTIC_PASSWORD;"));
    assert_eq!(
        command,
        "RESTIC_REPOSITORY='/tmp/restic' restic restore 'snapshot' --target './restorix-restore-test' --include '/data/volume'"
    );
}
