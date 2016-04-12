class project::techops_git (
  $code_path     = "/Users/${::boxen_user}/code",
  $email_address = $::work_email,
) {
 git::config::local { 'turn_puppet_email':
    ensure  => present,
    repo    => "${code_path}/turn/puppet",
    key     => 'user.email',
    value   => "${email_address}",
    require => Repository['turn-puppet'],
  }

  repository { 'turn-puppet':
    source  => 'ssh://git@stash.turn.com:7999/tops/puppet.git',
    path    => "${code_path}/turn/puppet",
    require => File["${code_path}/turn"],
  }

  git::config::local { 'turn_dns_email':
    ensure  => present,
    repo    => "${code_path}/turn/dns",
    key     => 'user.email',
    value   => "${email_address}",
    require => Repository['turn-dns'],
  }

  repository { 'turn-dns':
    source  => 'ssh://git@stash.turn.com:7999/tops/dns.git',
    path    => "${code_path}/turn/dns",
    require => File["${code_path}/turn"],
  }

  git::config::local { 'turn_nagios_email':
    ensure  => present,
    repo    => "${code_path}/turn/nagios",
    key     => 'user.email',
    value   => "${email_address}",
    require => Repository['turn-nagios'],
  }

  repository { 'turn-nagios':
    source  => 'ssh://git@stash.turn.com:7999/tops/nagios.git',
    path    => "${code_path}/turn/nagios",
    require => File["${code_path}/turn"],
  }
}
