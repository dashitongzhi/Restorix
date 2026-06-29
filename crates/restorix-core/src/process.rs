use crate::{RestorixError, Result};
use std::io::Read;
use std::process::{Child, Command, Output, Stdio};
use std::thread;
use std::time::{Duration, Instant};

#[cfg(unix)]
use std::os::unix::process::CommandExt;

pub fn run_with_timeout(
    mut command: Command,
    program: &str,
    args: &str,
    timeout: Duration,
) -> Result<Output> {
    #[cfg(unix)]
    command.process_group(0);

    command.stdout(Stdio::piped()).stderr(Stdio::piped());

    let mut child = command.spawn()?;
    let mut stdout = child.stdout.take();
    let mut stderr = child.stderr.take();
    let started_at = Instant::now();
    let stdout_reader = thread::spawn(move || {
        let mut data = Vec::new();
        if let Some(mut pipe) = stdout.take() {
            let _ = pipe.read_to_end(&mut data);
        }
        data
    });
    let stderr_reader = thread::spawn(move || {
        let mut data = Vec::new();
        if let Some(mut pipe) = stderr.take() {
            let _ = pipe.read_to_end(&mut data);
        }
        data
    });

    loop {
        if let Some(status) = child.try_wait()? {
            let stdout = stdout_reader.join().unwrap_or_default();
            let stderr = stderr_reader.join().unwrap_or_default();
            return Ok(Output {
                status,
                stdout,
                stderr,
            });
        }

        if started_at.elapsed() >= timeout {
            terminate_child_tree(&mut child);
            let _ = stdout_reader.join();
            let _ = stderr_reader.join();
            return Err(RestorixError::CommandTimedOut {
                program: program.to_string(),
                args: args.to_string(),
                seconds: timeout.as_secs(),
            });
        }

        thread::sleep(Duration::from_millis(100));
    }
}

fn terminate_child_tree(child: &mut Child) {
    #[cfg(unix)]
    {
        let process_group = format!("-{}", child.id());
        let _ = Command::new("kill")
            .args(["-TERM", &process_group])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
    }

    for _ in 0..10 {
        if matches!(child.try_wait(), Ok(Some(_))) {
            break;
        }
        thread::sleep(Duration::from_millis(100));
    }

    #[cfg(unix)]
    {
        let process_group = format!("-{}", child.id());
        let _ = Command::new("kill")
            .args(["-KILL", &process_group])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
    }

    let _ = child.kill();
    let _ = child.wait();
}
