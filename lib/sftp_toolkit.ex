defmodule SFTPToolkit do
  @moduledoc """
  A library that adds a lot of useful routines for the SFTP client for the Elixir
  programming language.

  It adds utility functions for:

  * recursive operations on the directories (creating, listing, removing), see
    `SFTPToolkit.Recursive`,
  * uploading files, see `SFTPToolkit.Upload`,
  * downloading files, see `SFTPToolkit.Download`.

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
  """
end
