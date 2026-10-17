//! Parent for an interactive Nushell.
//!
//! The terminal sends SIGHUP to the process it launched when the window
//! closes. Nushell panics and spins if that hangup arrives while a background
//! job still exists. This process stays in between, keeps Nushell in the
//! foreground, and turns SIGHUP into SIGKILL for that process group and any
//! direct child that has left it.
//!
//! A job that has already reparented away from Nushell is left alone.

use std::os::fd::BorrowedFd;
use std::os::unix::process::CommandExt;
use std::process::{exit, Command};
use std::sync::atomic::{AtomicBool, Ordering};

use nix::errno::Errno;
use nix::libc::{self, c_int};
use nix::sys::signal::{kill, sigaction, SaFlags, SigAction, SigHandler, SigSet, Signal};
use nix::sys::wait::{waitpid, WaitPidFlag, WaitStatus};
use nix::unistd::{getpgid, getpgrp, setpgid, tcsetpgrp, Pid};

const PKILL: &str = match option_env!("PKILL") {
    Some(path) => path,
    None => "/usr/bin/pkill",
};

static GOT_HUP: AtomicBool = AtomicBool::new(false);

extern "C" fn on_hup(_sig: c_int) {
    GOT_HUP.store(true, Ordering::Relaxed);
}

fn main() {
    let mut args = std::env::args_os();
    let _argv0 = args.next();
    let Some(program) = args.next() else {
        eprintln!("usage: nu-hup command [args...]");
        exit(2);
    };
    let arguments: Vec<_> = args.collect();

    let child = Command::new(&program)
        .args(&arguments)
        .process_group(0)
        .spawn();
    let child = match child {
        Ok(child) => child,
        Err(err) => {
            eprintln!("{}: {err}", program.to_string_lossy());
            exit(127);
        }
    };
    let child_pid = Pid::from_raw(child.id() as i32);
    // Drop would not reap it, but keep the pid and wait ourselves.
    std::mem::forget(child);

    if let Err(err) = setpgid(child_pid, child_pid) {
        if err != Errno::EACCES {
            eprintln!("setpgid: {err}");
        }
    }

    if let Err(err) = install_signals() {
        eprintln!("sigaction: {err}");
        exit(1);
    }

    if let Err(err) = tcsetpgrp(stdin_fd(), child_pid) {
        if err != Errno::ENOTTY && err != Errno::EBADF {
            eprintln!("tcsetpgrp: {err}");
        }
    }

    let status = loop {
        let waited = waitpid(child_pid, Some(WaitPidFlag::WUNTRACED));
        if GOT_HUP.load(Ordering::Relaxed) {
            kill_child_tree(child_pid);
            restore_tty();
            exit(129);
        }
        match waited {
            Err(Errno::EINTR) => continue,
            Err(err) => {
                eprintln!("waitpid: {err}");
                restore_tty();
                exit(1);
            }
            Ok(WaitStatus::Stopped(pid, _)) => {
                let _ = kill(Pid::from_raw(-pid.as_raw()), Signal::SIGCONT);
                let _ = tcsetpgrp(stdin_fd(), child_pid);
            }
            Ok(WaitStatus::Exited(_, code)) => break code,
            Ok(WaitStatus::Signaled(_, signal, _)) => break 128 + signal as i32,
            Ok(_) => {
                restore_tty();
                exit(1);
            }
        }
    };

    restore_tty();
    exit(status);
}

fn install_signals() -> Result<(), Errno> {
    let ignore = SigAction::new(SigHandler::SigIgn, SaFlags::empty(), SigSet::empty());
    for signal in [
        Signal::SIGINT,
        Signal::SIGQUIT,
        Signal::SIGTSTP,
        Signal::SIGTTIN,
        Signal::SIGTTOU,
    ] {
        unsafe { sigaction(signal, &ignore) }?;
    }

    // No SA_RESTART: waitpid must return so the hangup flag is observed.
    let hangup = SigAction::new(
        SigHandler::Handler(on_hup),
        SaFlags::empty(),
        SigSet::empty(),
    );
    unsafe { sigaction(Signal::SIGHUP, &hangup) }?;
    Ok(())
}

/// pkill has to run before Nushell dies. A child that left the process group
/// is reparented to launchd once its parent is gone, and a later scan misses it.
fn kill_direct_children(pid: Pid) {
    if pid.as_raw() <= 1 {
        return;
    }
    let _ = Command::new(PKILL)
        .args(["-9", "-P", &pid.as_raw().to_string()])
        .status();
}

fn kill_child_tree(child: Pid) {
    if child.as_raw() <= 1 {
        return;
    }

    kill_direct_children(child);
    if let Ok(pgid) = getpgid(Some(child)) {
        if pgid.as_raw() > 1 && pgid != getpgrp() {
            let _ = kill(Pid::from_raw(-pgid.as_raw()), Signal::SIGKILL);
        }
    }
    let _ = kill(child, Signal::SIGKILL);
}

fn stdin_fd() -> BorrowedFd<'static> {
    unsafe { BorrowedFd::borrow_raw(libc::STDIN_FILENO) }
}

fn restore_tty() {
    // macOS refuses this once Nushell's group is in the foreground. The session
    // leader can still exit; the terminal goes away with it.
    if let Err(err) = tcsetpgrp(stdin_fd(), getpgrp()) {
        if !matches!(err, Errno::ENOTTY | Errno::EBADF | Errno::EIO) {
            eprintln!("tcsetpgrp: {err}");
        }
    }
}
