# Add a fragment of an ssh known_hosts file
define ssh_knownhosts::fragment (
  $content = undef,
  $source  = undef
  ) {
    include ssh_knownhosts
    concat::fragment {"ssh_knownhosts_${title}":
      target  => $::ssh_knownhosts::path,
      source  => $source,
      content => $content,
    }
}
