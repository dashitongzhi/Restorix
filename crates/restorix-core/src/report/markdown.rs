mod localization;
mod sections;

use crate::models::ScanResult;
use localization::{label, yes_no, Label};
use sections::{
    push_line, render_errors, render_messages, render_protected, render_restore_commands,
    render_stale, render_unknown, render_unprotected,
};

pub use localization::ReportLanguage;

pub fn render_markdown_report(result: &ScanResult) -> String {
    render_markdown_report_with_language(result, ReportLanguage::English)
}

pub fn render_markdown_report_with_language(
    result: &ScanResult,
    language: ReportLanguage,
) -> String {
    let mut report = String::new();
    let summary = &result.summary;

    push_line(
        &mut report,
        &format!("# {}", label(language, Label::Report)),
    );
    push_line(
        &mut report,
        &format!(
            "{}: {}",
            label(language, Label::GeneratedAt),
            summary.scanned_at
        ),
    );
    push_line(&mut report, "");

    push_line(
        &mut report,
        &format!("## {}", label(language, Label::Summary)),
    );
    push_line(
        &mut report,
        &format!(
            "- Docker {}: {}",
            label(language, Label::Available),
            yes_no(language, summary.docker_available)
        ),
    );
    push_line(
        &mut report,
        &format!(
            "- Docker {}: {}",
            label(language, Label::Running),
            yes_no(language, summary.docker_running)
        ),
    );
    push_line(
        &mut report,
        &format!(
            "- Restic {}: {}",
            label(language, Label::Available),
            yes_no(language, summary.restic_available)
        ),
    );
    push_line(
        &mut report,
        &format!(
            "- {}: {}",
            label(language, Label::TotalContainers),
            summary.total_containers
        ),
    );
    push_line(
        &mut report,
        &format!(
            "- {}: {}",
            label(language, Label::TotalVolumes),
            summary.total_volumes
        ),
    );
    push_line(
        &mut report,
        &format!(
            "- {}: {}",
            label(language, Label::Protected),
            summary.protected_count
        ),
    );
    push_line(
        &mut report,
        &format!(
            "- {}: {}",
            label(language, Label::Unprotected),
            summary.unprotected_count
        ),
    );
    push_line(
        &mut report,
        &format!(
            "- {}: {}",
            label(language, Label::Stale),
            summary.stale_count
        ),
    );
    push_line(
        &mut report,
        &format!(
            "- {}: {}",
            label(language, Label::Unknown),
            summary.unknown_count
        ),
    );
    push_line(
        &mut report,
        &format!(
            "- {}: {}",
            label(language, Label::Errors),
            summary.error_count
        ),
    );
    push_line(&mut report, "");

    render_unprotected(&mut report, &result.volume_health, language);
    render_stale(&mut report, &result.volume_health, language);
    render_unknown(&mut report, &result.volume_health, language);
    render_errors(&mut report, &result.volume_health, language);
    render_protected(&mut report, &result.volume_health, language);
    render_restore_commands(&mut report, &result.volume_health, language);
    render_messages(&mut report, Label::Warnings, &result.warnings, language);
    render_messages(&mut report, Label::Errors, &result.errors, language);

    report
}
