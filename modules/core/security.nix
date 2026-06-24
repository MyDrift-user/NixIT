# Core security hardening - shared across all machines
{ ... }: {
  boot.kernel.sysctl = {
    # Pointer and log restrictions
    "kernel.kptr_restrict"                      = 2;
    "kernel.dmesg_restrict"                     = 1;
    "kernel.yama.ptrace_scope"                  = 1;

    # Disable magic SysRq
    "kernel.sysrq"                              = 0;

    # Restrict perf and BPF
    "kernel.perf_event_paranoid"                = 3;
    "kernel.unprivileged_bpf_disabled"          = 1;
    "net.core.bpf_jit_harden"                   = 2;

    # IPv4 network hardening
    "net.ipv4.conf.all.rp_filter"               = 1;
    "net.ipv4.conf.default.rp_filter"           = 1;
    "net.ipv4.conf.all.accept_redirects"        = 0;
    "net.ipv4.conf.default.accept_redirects"    = 0;
    "net.ipv4.conf.all.send_redirects"          = 0;
    "net.ipv4.conf.default.send_redirects"      = 0;
    "net.ipv4.conf.all.log_martians"            = 1;
    "net.ipv4.conf.default.log_martians"        = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts"      = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # TCP hardening
    "net.ipv4.tcp_syncookies"                   = 1;
    "net.ipv4.tcp_rfc1337"                      = 1;

    # IPv6 hardening
    "net.ipv6.conf.all.accept_redirects"        = 0;
    "net.ipv6.conf.default.accept_redirects"    = 0;
  };

  # Blacklist uncommon/dangerous network protocols
  boot.blacklistedKernelModules = [
    "dccp" "sctp" "rds" "tipc"
  ];

  security.auditd.enable = true;
  security.audit = {
    enable = true;
    rules = [
      "-a always,exit -F arch=b64 -S execve -k exec"
      "-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -k perm_change"
      "-w /etc/passwd  -p wa -k identity"
      "-w /etc/group   -p wa -k identity"
      "-w /etc/shadow  -p wa -k identity"
      "-w /etc/sudoers -p wa -k sudoers"
      "-w /etc/sudoers.d -p wa -k sudoers"
    ];
  };

  security.pam.services.su.requireWheel = true;

  boot.tmp = {
    useTmpfs  = true;
    tmpfsSize = "2G";
  };

  security.protectKernelImage = true;

  systemd.coredump.enable = false;
  security.pam.loginLimits = [{
    domain = "*";
    type   = "hard";
    item   = "core";
    value  = "0";
  }];
}
