class people::johann8384 {
  include docker
  include virtualbox
  include chrome
  include iterm2::colors::solarized_dark
  include iterm2::stable
  include java
  include wget
  include screen
  include slack
  include steam
  include hub
  include bash
  include bash::completion
  include vagrant
  vagrant::plugin { 'vagrant-dns': }
  vagrant::plugin { 'vagrant-vbguest': }
  package { 'qt': }

  $home  = "/Users/${::boxen_user}"
  $code  = "${home}/code"

  file { $code:
    ensure  => directory
  }

  file { "${code}/turn":
    ensure  => directory,
    require => File[$code],
  }

  # Git
  git::config::global { 'alias.master': value => '!git checkout master && git pull origin master' }
  git::config::global { 'user.name': value => 'Jonathan Creasy' }
  git::config::global { 'user.email': value => $::github_email }
  git::config::global { 'rebase.autosquash': value => 'true' }
  git::config::global { 'color.ui': value => 'true' }
  git::config::global { 'color.branch': value => 'auto' }
  git::config::global { 'color.status': value => 'auto' }
  git::config::global { 'color.diff': value => 'auto' }
  git::config::global { 'color.showbranch': value => 'auto' }
  git::config::global { 'core.editor': value => 'nano' }
  git::config::global { 'core.whitespace': value => 'fix,-indent-with-non-tab,trailing-space,cr-at-eol' }
  git::config::global { 'apply.whitespace': value => 'nowarn' }
  git::config::global { 'branch.autosetuprebase': value => 'always' }
  git::config::global { 'log.date': value => 'relative' }
  git::config::global { 'alias.st': value => 'status -sb' }
  git::config::global { 'alias.ci': value => 'commit' }
  git::config::global { 'alias.co': value => 'checkout' }
  git::config::global { 'alias.br': value => 'branch' }
  git::config::global { 'format.pretty': value => '%C(yellow)%h%Creset %C(magenta)%cd%Creset %d %s' }

  include ::projects::techops_git

  ::stdrepo::repo { ['opentsdb', 'tcollector', 'opentsdb-discoveryplugins', 'splicer', 'opentsdb.net']: }

  repository { 'scopatz-nanorc':
    source => 'scopatz/nanorc',
    path => "${home}/.nano",
  }

  # .bash_profile
  file { "${home}/.bash_profile":
    source => 'puppet:///modules/people/johann8384/bash_profile',
  }

  file { "${home}/.hushlogin":
    content => '# The mere presence of this file in the home directory disables the system copyright notice, the date and time of the last login, the message of the day as well as other information that may otherwise appear on login.'
  }

  file { "${home}/.gitattributes":
    source => 'puppet:///modules/people/johann8384/gitattributes',
  }

  file { "${home}/.functions":
    source => 'puppet:///modules/people/johann8384/functions',
  }

  file { "${home}/.aliases":
    source => 'puppet:///modules/people/johann8384/aliases',
  }

  file { "${home}/.exports":
    source => 'puppet:///modules/people/johann8384/exports',
  }

  file { "${home}/.path":
    source => 'puppet:///modules/people/johann8384/path',
  }

  file { "${home}/.nanorc":
    source => 'puppet:///modules/people/johann8384/nanorc',
  }

  file { "${home}/.inputrc":
    source => 'puppet:///modules/people/johann8384/inputrc',
  }

  file { "${home}/.bash_prompt":
    source => 'puppet:///modules/people/johann8384/bash_prompt',
  }

  file { "${home}/.npmrc":
    source => 'puppet:///modules/people/johann8384/npmrc',
  }

  file { "${home}/.pylintrc":
    source => 'puppet:///modules/people/johann8384/pylintrc',
  }

  file { "${home}/.screenrc":
    source => 'puppet:///modules/people/johann8384/screenrc',
  }

  file { "${home}/.viminfo":
    source => 'puppet:///modules/people/johann8384/viminfo',
  }

  file { "${home}/.vimrc":
    source => 'puppet:///modules/people/johann8384/vimrc',
  }

  file { "${home}/.gitexcludes":
    source => 'puppet:///modules/people/johann8384/gitexcludes',
  }

  file { "${home}/bin":
    ensure  => directory,
    source  => 'puppet:///modules/people/johann8384/bin',
    recurse => true,
    force   => true,
    owner   => $::boxen_user,
    group   => 'staff',
  }

  sudoers { "${boxen_user}_sudo":
    users    => $::boxen_user,
    type     => 'user_spec',
    commands => '(ALL) NOPASSWD: ALL',
    hosts    => 'ALL',
    comment  => 'Stop asking me to sudo',
  }

  homebrew::tap { 'homebrew/dupes': }

  package { ['nano', 'awscli', 'gradle', 'maven']:
    ensure => latest,
  }

  package {
    [
      'ansible',
      'go',
      'gpg-agent',
      'git',
      'bash-git-prompt',
      'gpg',
      'tmux',
      'tree',
      'zookeeper',
      'influxdb',
      'elasticsearch',
      'rabbitmq',
    ]:
    ensure => present,
  }

  package { 'python':
    ensure => present,
  } ->
  package {
    ['virtualenv', 'pylint', 'virtualenvwrapper']:
    ensure   => present,
    provider => pip,
  }

  class { 'ssh_config': }
  ssh_config::fragment{ 'user':
    content => template('people/johann8384/ssh_config.erb'),
  }

  class { 'ssh_knownhosts': }
  ssh_knownhosts::fragment{ 'knownhosts-stash':
    content => "[stash.turn.com]:7999,[172.19.112.138]:7999 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCT0kLxviKeI69ughXCkKugolcYCoqLpVcjrIP70zpl/sqKyiQoOxgbis1ekfUp8nnBGSkUx3m3aE6jc6zRwpXdCWx0vm1mA/V7Y48V71oeNs189hmodCekv9LiKyYr+uWsvTqu/igS1buLLxVZg4br6/cs6UdH0eA7v/MdsXuFM6tnqe3GLuscA4r2jcYifaJj+6PMJDC0x8p/1hewn3dDnANnayM3qdtB/VdLTDkqg8kF3kNqod6lt9npy9c3dCEPZyttolRaqM8+oRlltIYAlNw3bpOhna6jdP9EP6bs9XVHHc0tlM3CIqq6I3sW1fwlZGtFbB9AbMkGb9P9xpBp",
  }

  include osx::no_network_dsstores
  include osx::dock::autohide
  include osx::disable_app_quarantine
  include osx::global::disable_autocorrect
  include osx::global::tap_to_click

  class { 'osx::global::natural_mouse_scrolling':
    enabled => true
  }

  boxen::osx_defaults { 'enable trackpad three-finger drag':
    ensure => present,
    domain => 'com.apple.driver.AppleBluetoothMultitouch.trackpad',
    key    => 'TrackpadThreeFingerDrag',
    value  => '1',
    user   => $::boxen_user,
  }
  boxen::osx_defaults { 'show battery percentage remaining':
    ensure => present,
    domain => 'com.apple.menuextra.battery',
    key    => 'ShowPercent',
    type   => 'string',
    value  => 'YES',
    user   => $::boxen_user,
  }

}
