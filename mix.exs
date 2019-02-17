defmodule SFTPToolkit.MixProject do
  use Mix.Project

  def project do
    [
      app: :sftp_toolkit,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:ssh]
    ]
  end

  defp deps do
    [
      {:bunch, "~> 0.1.2"},
    ]
  end
end
