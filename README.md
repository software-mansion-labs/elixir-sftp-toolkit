# SFTPToolkit

[![Hex.pm](https://img.shields.io/hexpm/v/sftp_toolkit.svg)](https://hex.pm/packages/sftp_toolkit)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/sftp_toolkit/)
[![CircleCI](https://circleci.com/gh/SoftwareMansion/elixir-sftp-toolkit/tree/master.svg?style=shield)](https://circleci.com/gh/SoftwareMansion/elixir-sftp-toolkit/tree/master)

A library that adds a lot of useful routines for the SFTP client for the Elixir
programming language.

It adds utility functions for:

* recursive operations on the directories (creating, listing, removing),
* uploading files,
* downloading files.

It is fully compatible with Erlang's `:ssh_sftp` module and introduces no
unnecessary abstraction layer.

## Installation

The package can be installed by adding `sftp_toolkit` to your list of dependencies 
in `mix.exs`:

```elixir
def deps do
  [
    {:sftp_toolkit, "~> 1.0"}
  ]
end
```

## Copyright and License

Copyright 2019, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=sftp_toolkit)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](
https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=sftp_toolkit)

Licensed under the [Apache License, Version 2.0](LICENSE)
