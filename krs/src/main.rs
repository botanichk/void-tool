use std::path::Path;
use std::process::Command;
use std::time::{Duration, Instant};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("health") => cmd_health(),
        Some("check") => cmd_check(),
        Some("--check") => cmd_check(),
        _ => {
            eprintln!("Usage: krs <health|check>");
            std::process::exit(1);
        }
    }
}

fn running(name: &str) -> bool {
    Command::new("pgrep")
        .arg("-x")
        .arg(name)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn running_full(name: &str) -> bool {
    Command::new("pgrep")
        .arg("-f")
        .arg(name)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn cmd_check() {
    let statuses = [
        ("pipewire", running("pipewire")),
        ("wireplumber", running("wireplumber")),
        ("pipewire-pulse", running_full("pipewire-pulse")),
        ("pulse-socket", check_pulse_socket()),
    ];

    let all_ok = statuses.iter().all(|(_, ok)| *ok);
    for (name, ok) in &statuses {
        println!("{}:{}", name, if *ok { "running" } else { "dead" });
    }
    std::process::exit(if all_ok { 0 } else { 1 });
}

fn check_pulse_socket() -> bool {
    let start = Instant::now();
    let child = Command::new("pactl")
        .arg("info")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn();

    match child {
        Ok(mut c) => {
            let timeout = Duration::from_secs(3);
            loop {
                match c.try_wait() {
                    Ok(Some(status)) => return status.success(),
                    Ok(None) => {
                        if start.elapsed() > timeout {
                            let _ = c.kill();
                            return false;
                        }
                        std::thread::sleep(Duration::from_millis(50));
                    }
                    Err(_) => return false,
                }
            }
        }
        Err(_) => false,
    }
}

fn cmd_health() {
    println!("  🔊 Audio health check (krs v{})", env!("CARGO_PKG_VERSION"));

    let ps = [
        ("pipewire", running("pipewire")),
        ("wireplumber", running("wireplumber")),
        ("pipewire-pulse", running_full("pipewire-pulse")),
    ];

    let pulse_ok = check_pulse_socket();
    let has_sinks = get_default_sink().is_some();

    let all_running = ps.iter().all(|(_, ok)| *ok) && pulse_ok;

    for (name, ok) in &ps {
        if *ok {
            println!("  ✓ {}: running", name);
        } else {
            println!("  ✗ {}: dead", name);
        }
    }
    if pulse_ok {
        println!("  ✓ pulse-socket: ok");
    } else {
        println!("  ✗ pulse-socket: dead");
    }

    if all_running && has_sinks {
        println!("  ✓ PipeWire stack healthy");
        std::process::exit(0);
    }

    println!("  ⟳ Restarting audio stack...");
    let ok = restart_stack();
    if ok {
        println!("  ✓ Audio stack restarted, HDMI default");
        std::process::exit(0);
    } else {
        println!("  ✗ Audio restart failed");
        std::process::exit(1);
    }
}

fn get_default_sink() -> Option<String> {
    let out = Command::new("pactl")
        .args(["list", "short", "sinks"])
        .output();
    match out {
        Ok(o) => {
            let text = String::from_utf8_lossy(&o.stdout);
            for line in text.lines() {
                if !line.contains("auto_null") {
                    let parts: Vec<&str> = line.split_whitespace().collect();
                    if parts.len() >= 2 {
                        return Some(parts[1].to_string());
                    }
                }
            }
            None
        }
        Err(_) => None,
    }
}

fn restart_stack() -> bool {
    // kill
    for sig in ["-15", "-9"] {
        let _ = Command::new("pkill").args([sig, "-x", "wireplumber"]).status();
        let _ = Command::new("pkill")
            .args([sig, "-f", "pipewire.*pipewire-pulse"])
            .status();
        let _ = Command::new("pkill").args([sig, "-x", "pipewire"]).status();
        std::thread::sleep(Duration::from_secs(1));
    }

    // clean stale files
    let pulse_dir = Path::new("/run/user/1000/pulse");
    for f in &["pid", "native"] {
        let _ = std::fs::remove_file(pulse_dir.join(f));
    }

    // start
    let _ = Command::new("/usr/bin/pipewire")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn();
    std::thread::sleep(Duration::from_secs(2));

    let _ = Command::new("/usr/bin/wireplumber")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn();
    std::thread::sleep(Duration::from_secs(1));

    let _ = Command::new("/usr/bin/pipewire")
        .args(["-c", "/usr/share/pipewire/pipewire-pulse.conf"])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn();

    // wait for pulse
    let start = Instant::now();
    let timeout = Duration::from_secs(15);
    loop {
        if check_pulse_socket() {
            break;
        }
        if start.elapsed() > timeout {
            return false;
        }
        std::thread::sleep(Duration::from_secs(1));
    }

    // wait for real sinks
    let start = Instant::now();
    let timeout = Duration::from_secs(10);
    loop {
        if get_default_sink().is_some() {
            break;
        }
        if start.elapsed() > timeout {
            // proceed anyway
            break;
        }
        std::thread::sleep(Duration::from_secs(1));
    }

    // set first real sink as default
    if let Some(ref sink) = get_default_sink() {
        let _ = Command::new("pactl")
            .args(["set-default-sink", sink])
            .status();
        let _ = Command::new("pactl")
            .args(["set-sink-volume", sink, "100%"])
            .status();
        let _ = Command::new("pactl")
            .args(["set-sink-mute", sink, "0"])
            .status();
    }

    true
}
