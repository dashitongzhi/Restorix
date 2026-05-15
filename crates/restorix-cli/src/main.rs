use anyhow::Result;
use clap::{ArgAction, Args, Parser, Subcommand};
use restorix_core::commands;
use restorix_core::storage::config::ConfigStore;

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
    Set { key: String, value: String },
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let config_store = ConfigStore::default()?;

    match cli.command {
        Command::Scan(_) => print_json(&commands::scan_json(&config_store))?,
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
                    args.enabled,
                )?;
                print_json(&repo)?;
            }
            RepoCommand::List(_) => print_json(&commands::list_repositories(&config_store)?)?,
            RepoCommand::Remove { repo_id } => {
                let removed = commands::remove_repository(&config_store, &repo_id)?;
                print_json(&serde_json::json!({ "removed": removed }))?;
            }
            RepoCommand::Test(args) => {
                print_json(&commands::test_repository(&config_store, &args.repo_id)?)?
            }
        },
        Command::Report { command } => match command {
            ReportCommand::Markdown(args) => {
                print!(
                    "{}",
                    commands::markdown_report_with_language(&config_store, &args.language)
                );
            }
        },
        Command::Config { command } => match command {
            ConfigCommand::Get(_) => print_json(&commands::get_config(&config_store)?)?,
            ConfigCommand::Set { key, value } => {
                print_json(&commands::set_config(&config_store, &key, &value)?)?
            }
        },
    }

    Ok(())
}

fn print_json<T: serde::Serialize>(value: &T) -> Result<()> {
    println!("{}", serde_json::to_string_pretty(value)?);
    Ok(())
}
