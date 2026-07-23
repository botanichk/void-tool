use std::env;
use std::path::{Path, PathBuf};
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

fn runtime_dir() -> PathBuf {
    env::var("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/run/user/1000"))
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

fn wp_is_stuck() -> bool {
    let log_path = Path::new("/tmp/void-tool-wp.log");
    if !log_path.exists() {
        return false;
    }
    match std::fs::read_to_string(log_path) {
        Ok(content) => content.contains("Unexpected reply"),
        Err(_) => false,
    }
}

fn restart_dbus() -> bool {
    let dbus_pid_path = runtime_dir().join("dbus.pid");

    if dbus_pid_path.exists() {
        if let Ok(pid_str) = std::fs::read_to_string(&dbus_pid_path) {
            if let Ok(pid) = pid_str.trim().parse::<i32>() {
                let _ = Command::new("kill")
                    .arg(pid.to_string())
                    .stdout(std::process::Stdio::null())
                    .stderr(std::process::Stdio::null())
                    .status();
            }
        }
        std::thread::sleep(Duration::from_secs(2));
    }

    let bus_addr = format!("unix:path={}/bus", runtime_dir().display());
    let _ = Command::new("dbus-daemon")
        .args(["--session", "--nofork", "--address", &bus_addr])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn();

    for _ in 0..10 {
        std::thread::sleep(Duration::from_millis(500));
        let r = Command::new("timeout")
            .args(["2", "dbus-send", "--session", "--dest=org.freedesktop.DBus",
                   "--type=method_call", "--print-reply", "/org/freedesktop/DBus",
                   "org.freedesktop.DBus.ListNames"])
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .status();
        if let Ok(status) = r {
            if status.success() {
                return true;
            }
        }
    }
    false
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
    let pulse_dir = runtime_dir().join("pulse");
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
    let pulse_came = loop {
        if check_pulse_socket() {
            break true;
        }
        if start.elapsed() > timeout {
            break false;
        }
        std::thread::sleep(Duration::from_secs(1));
    };

    if !pulse_came {
        if wp_is_stuck() {
            println!("  ⟳ WirePlumber stuck on D-Bus — restarting session bus...");
            // kill again
            for sig in ["-15", "-9"] {
                let _ = Command::new("pkill").args([sig, "-x", "wireplumber"]).status();
                let _ = Command::new("pkill")
                    .args([sig, "-f", "pipewire.*pipewire-pulse"])
                    .status();
                let _ = Command::new("pkill").args([sig, "-x", "pipewire"]).status();
                std::thread::sleep(Duration::from_secs(1));
            }
            if !restart_dbus() {
                return false;
            }
            // restart stack again
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
            // wait again
            let start = Instant::now();
            let timeout = Duration::from_secs(15);
            let ok = loop {
                if check_pulse_socket() {
                    break true;
                }
                if start.elapsed() > timeout {
                    break false;
                }
                std::thread::sleep(Duration::from_secs(1));
            };
            if !ok {
                return false;
            }
        } else {
            return false;
        }
    }

    // wait for real sinks
    let start = Instant::now();
    let timeout = Duration::from_secs(10);
    loop {
        if get_default_sink().is_some() {
            break;
        }
        if start.elapsed() > timeout {
            return false;
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
