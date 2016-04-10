# manage user ssh config
# uses puppetlabs-concat to enable separate sections to be managed separately
class ssh_knownhosts {
    $path = "/Users/${::luser}/.ssh/known_hosts"
    concat { $path:
      mode    => '0644',
      owner   => $::luser,
      group   => 'staff',
    }
}
