use super::localization::{label, localized_message, Label, ReportLanguage};
use crate::models::{HealthStatus, VolumeHealth};

pub(super) fn render_errors(
    report: &mut String,
    health: &[VolumeHealth],
    language: ReportLanguage,
) {
    let rows = health
        .iter()
        .filter(|item| item.status == HealthStatus::Error)
        .collect::<Vec<_>>();
    if rows.is_empty() {
        return;
    }

    push_line(
        report,
        &format!("## {}", label(language, Label::ErrorVolumes)),
    );
    push_line(
        report,
        &format!(
            "| {} | {} | {} |",
            label(language, Label::Volume),
            label(language, Label::Mountpoint),
            label(language, Label::Reason)
        ),
    );
    push_line(report, "|---|---|---|");
    for item in rows {
        push_line(
            report,
            &format!(
                "| {} | {} | {} |",
                escape_table(&item.volume.name),
                escape_table(&item.volume.mountpoint),
                escape_table(&localized_message(language, &item.reason))
            ),
        );
    }
    push_line(report, "");
}

pub(super) fn render_unknown(
    report: &mut String,
    health: &[VolumeHealth],
    language: ReportLanguage,
) {
    let rows = health
        .iter()
        .filter(|item| item.status == HealthStatus::Unknown)
        .collect::<Vec<_>>();
    if rows.is_empty() {
        return;
    }

    push_line(
        report,
        &format!("## {}", label(language, Label::UnknownVolumes)),
    );
    push_line(
        report,
        &format!(
            "| {} | {} | {} |",
            label(language, Label::Volume),
            label(language, Label::Mountpoint),
            label(language, Label::Reason)
        ),
    );
    push_line(report, "|---|---|---|");
    for item in rows {
        push_line(
            report,
            &format!(
                "| {} | {} | {} |",
                escape_table(&item.volume.name),
                escape_table(&item.volume.mountpoint),
                escape_table(&localized_message(language, &item.reason))
            ),
        );
    }
    push_line(report, "");
}

pub(super) fn render_unprotected(
    report: &mut String,
    health: &[VolumeHealth],
    language: ReportLanguage,
) {
    let rows = health
        .iter()
        .filter(|item| item.status == HealthStatus::Unprotected)
        .collect::<Vec<_>>();
    if rows.is_empty() {
        return;
    }

    push_line(
        report,
        &format!("## {}", label(language, Label::UnprotectedVolumes)),
    );
    push_line(
        report,
        &format!(
            "| {} | {} | {} |",
            label(language, Label::Volume),
            label(language, Label::Mountpoint),
            label(language, Label::Reason)
        ),
    );
    push_line(report, "|---|---|---|");
    for item in rows {
        push_line(
            report,
            &format!(
                "| {} | {} | {} |",
                escape_table(&item.volume.name),
                escape_table(&item.volume.mountpoint),
                escape_table(&localized_message(language, &item.reason))
            ),
        );
    }
    push_line(report, "");
}

pub(super) fn render_stale(report: &mut String, health: &[VolumeHealth], language: ReportLanguage) {
    let rows = health
        .iter()
        .filter(|item| item.status == HealthStatus::Stale)
        .collect::<Vec<_>>();
    if rows.is_empty() {
        return;
    }

    push_line(
        report,
        &format!("## {}", label(language, Label::StaleVolumes)),
    );
    push_line(
        report,
        &format!(
            "| {} | {} | {} | {} |",
            label(language, Label::Volume),
            label(language, Label::LastBackup),
            label(language, Label::AgeHours),
            label(language, Label::Reason)
        ),
    );
    push_line(report, "|---|---:|---:|---|");
    for item in rows {
        push_line(
            report,
            &format!(
                "| {} | {} | {:.1} | {} |",
                escape_table(&item.volume.name),
                escape_table(
                    item.last_backup_time
                        .as_deref()
                        .unwrap_or(label(language, Label::Unknown)),
                ),
                item.backup_age_hours.unwrap_or_default(),
                escape_table(&localized_message(language, &item.reason))
            ),
        );
    }
    push_line(report, "");
}

pub(super) fn render_protected(
    report: &mut String,
    health: &[VolumeHealth],
    language: ReportLanguage,
) {
    let rows = health
        .iter()
        .filter(|item| item.status == HealthStatus::Protected)
        .collect::<Vec<_>>();
    if rows.is_empty() {
        return;
    }

    push_line(
        report,
        &format!("## {}", label(language, Label::ProtectedVolumes)),
    );
    push_line(
        report,
        &format!(
            "| {} | {} | {} |",
            label(language, Label::Volume),
            label(language, Label::LastBackup),
            label(language, Label::Repository)
        ),
    );
    push_line(report, "|---|---:|---|");
    for item in rows {
        push_line(
            report,
            &format!(
                "| {} | {} | {} |",
                escape_table(&item.volume.name),
                escape_table(
                    item.last_backup_time
                        .as_deref()
                        .unwrap_or(label(language, Label::Unknown)),
                ),
                escape_table(
                    item.matched_repository_id
                        .as_deref()
                        .unwrap_or(label(language, Label::Unknown)),
                )
            ),
        );
    }
    push_line(report, "");
}

pub(super) fn render_restore_commands(
    report: &mut String,
    health: &[VolumeHealth],
    language: ReportLanguage,
) {
    let rows = health
        .iter()
        .filter(|item| item.restore_command.is_some())
        .collect::<Vec<_>>();
    if rows.is_empty() {
        return;
    }

    push_line(
        report,
        &format!("## {}", label(language, Label::RestoreCommands)),
    );
    for item in rows {
        push_line(report, &format!("### {}", item.volume.name));
        push_line(report, "```bash");
        push_line(report, item.restore_command.as_deref().unwrap_or_default());
        push_line(report, "```");
    }
    push_line(report, "");
}

pub(super) fn render_messages(
    report: &mut String,
    title: Label,
    messages: &[String],
    language: ReportLanguage,
) {
    if messages.is_empty() {
        return;
    }

    push_line(report, &format!("## {}", label(language, title)));
    for message in messages {
        push_line(
            report,
            &format!("- {}", localized_message(language, message)),
        );
    }
    push_line(report, "");
}

pub(super) fn push_line(report: &mut String, line: &str) {
    report.push_str(line);
    report.push('\n');
}

fn escape_table(value: &str) -> String {
    value.replace('|', "\\|")
}
