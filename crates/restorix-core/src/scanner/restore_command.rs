use crate::models::BackupRepository;

pub fn build_restore_command(
    repo: &BackupRepository,
    snapshot_id: &str,
    include_path: &str,
) -> String {
    let password_assignment = repo
        .password_env_key
        .as_deref()
        .filter(|key| is_valid_environment_key(key))
        .map(|key| {
            format!(" RESTIC_PASSWORD=\"${{{key}:?Set {key} before running this command}}\"")
        })
        .unwrap_or_default();

    format!(
        "RESTIC_REPOSITORY={}{} restic restore {} --target {} --include {}",
        shell_quote(&repo.location),
        password_assignment,
        shell_quote(snapshot_id),
        shell_quote("./restorix-restore-test"),
        shell_quote(include_path)
    )
}

fn shell_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', "'\"'\"'"))
}

fn is_valid_environment_key(key: &str) -> bool {
    let mut characters = key.chars();
    matches!(characters.next(), Some(character) if character == '_' || character.is_ascii_alphabetic())
        && characters.all(|character| character == '_' || character.is_ascii_alphanumeric())
}
