use anyhow::{bail, Result};
use clap::{ArgAction, Args, Parser, Subcommand};
use restorix_core::commands;
use restorix_core::storage::config::{ConfigStore, SettingsDraft};

#[derive(Debug, Parser)]
#[command(name = "restorix")]
#[command(about = "Check whether Docker volumes are backed up and restorable.")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    Scan(JsonFlag),
    Docker {
        #[command(subcommand)]
        command: DockerCommand,
    },
    Repo {
        #[command(subcommand)]
        command: RepoCommand,
    },
    Report {
        #[command(subcommand)]
        command: ReportCommand,
    },
    Config {
        #[command(subcommand)]
        command: ConfigCommand,
    },
}

#[derive(Debug, Args)]
struct JsonFlag {
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Subcommand)]
enum DockerCommand {
    Check(JsonFlag),
    Containers(JsonFlag),
    Volumes(JsonFlag),
}

#[derive(Debug, Subcommand)]
enum RepoCommand {
    Add(RepoAddArgs),
    List(JsonFlag),
    Remove { repo_id: String },
    Enable { repo_id: String },
    Disable { repo_id: String },
    Test(RepoTestArgs),
}

#[derive(Debug, Args)]
struct RepoAddArgs {
    #[arg(long)]
    tool: String,
    #[arg(long)]
    name: String,
    #[arg(long)]
    location: String,
    #[arg(long = "password-env-key")]
    password_env_key: Option<String>,
    #[arg(long = "expected-hostname")]
    expected_hostname: Option<String>,
    #[arg(long, default_value_t = true, action = ArgAction::Set)]
    enabled: bool,
}

#[derive(Debug, Args)]
struct RepoTestArgs {
    repo_id: String,
    #[arg(long)]
    json: bool,
}

#[derive(Debug, Subcommand)]
enum ReportCommand {
    Markdown(ReportMarkdownArgs),
}

#[derive(Debug, Args)]
struct ReportMarkdownArgs {
    #[arg(long, default_value = "en")]
    language: String,
}

#[derive(Debug, Subcommand)]
enum ConfigCommand {
    Get(JsonFlag),
    Commit {
        payload: String,
    },
    #[command(hide = true)]
    Set {
        key: String,
        value: String,
    },
}

fn main() -> Result<()> {
    let exit_code = run()?;
    if exit_code != 0 {
        std::process::exit(exit_code);
    }
    Ok(())
}

fn run() -> Result<i32> {
    let cli = Cli::parse();
    let config_store = ConfigStore::from_default_path()?;
    let mut exit_code = 0;

    match cli.command {
        Command::Scan(_) => {
            let output = commands::scan_result(&config_store);
            print_json(&output.value)?;
            exit_code = output.exit_code;
        }
        Command::Docker { command } => match command {
            DockerCommand::Check(_) => print_json(&commands::docker_check_json())?,
            DockerCommand::Containers(_) => print_json(&commands::docker_containers_json()?)?,
            DockerCommand::Volumes(_) => print_json(&commands::docker_volumes_json()?)?,
        },
        Command::Repo { command } => match command {
            RepoCommand::Add(args) => {
                let repo = commands::add_repository(
                    &config_store,
                    &args.tool,
                    args.name,
                    args.location,
                    args.password_env_key,
                    args.expected_hostname,
                    args.enabled,
                )?;
                print_json(&repo)?;
            }
            RepoCommand::List(_) => print_json(&commands::list_repositories(&config_store)?)?,
            RepoCommand::Remove { repo_id } => {
                let removed = commands::remove_repository(&config_store, &repo_id)?;
                print_json(&serde_json::json!({ "removed": removed }))?;
            }
            RepoCommand::Enable { repo_id } => {
                print_json(&commands::set_repository_enabled(
                    &config_store,
                    &repo_id,
                    true,
                )?)?;
            }
            RepoCommand::Disable { repo_id } => {
                print_json(&commands::set_repository_enabled(
                    &config_store,
                    &repo_id,
                    false,
                )?)?;
            }
            RepoCommand::Test(args) => {
                print_json(&commands::test_repository(&config_store, &args.repo_id)?)?
            }
        },
        Command::Report { command } => match command {
            ReportCommand::Markdown(args) => {
                let output = commands::markdown_report(&config_store, &args.language);
                print!("{}", output.value);
                exit_code = output.exit_code;
            }
        },
        Command::Config { command } => match command {
            ConfigCommand::Get(_) => print_json(&commands::get_config(&config_store)?)?,
            ConfigCommand::Commit { payload } => {
                let draft = serde_json::from_str::<SettingsDraft>(&payload)?;
                print_json(&commands::commit_settings(&config_store, draft)?)?
            }
            ConfigCommand::Set { key, value } => {
                let draft = legacy_settings_draft(&config_store, &key, &value)?;
                print_json(&commands::commit_settings(&config_store, draft)?)?
            }
        },
    }

    Ok(exit_code)
}

fn legacy_settings_draft(
    config_store: &ConfigStore,
    key: &str,
    value: &str,
) -> Result<SettingsDraft> {
    let config = config_store.load()?;
    let mut draft = SettingsDraft::from(&config);
    match key {
        "stale_hours" => {
            draft.stale_hours = value
                .parse::<u64>()
                .map_err(|_| anyhow::anyhow!("stale_hours must be an integer."))?;
        }
        "loose_matching" => draft.loose_matching = parse_legacy_bool(value)?,
        "show_dock_icon" => draft.show_dock_icon = parse_legacy_bool(value)?,
        "launch_at_login" => draft.launch_at_login = parse_legacy_bool(value)?,
        "notifications_enabled" => draft.notifications_enabled = parse_legacy_bool(value)?,
        "cli_path" => draft.cli_path = value.to_string(),
        other => bail!("Unknown config key: {other}"),
    }
    Ok(draft)
}

fn parse_legacy_bool(value: &str) -> Result<bool> {
    match value {
        "true" | "1" | "yes" | "on" => Ok(true),
        "false" | "0" | "no" | "off" => Ok(false),
        _ => bail!("Boolean value must be true or false."),
    }
}

fn print_json<T: serde::Serialize>(value: &T) -> Result<()> {
    println!("{}", serde_json::to_string_pretty(value)?);
    Ok(())
}
