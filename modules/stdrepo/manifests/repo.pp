define stdrepo::repo (
  $source = $github_login,
  $email  = $github_email,
  $path   = "/Users/${::boxen_user}/code"
  ) {
    repository { "${source}-${title}":
      source => "${source}/${title}",
      path   => "${path}/${title}",
    }

   git::config::local { "${source}-${title}-email":
      ensure  => present,
      repo    => "${path}/${title}",
      key     => 'user.email',
      value   => "${email}",
      require => Repository["${source}-${title}"],
    }
}
