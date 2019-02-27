defmodule SFTPToolkit.MixProject do
  use Mix.Project

  def project do
    [
      app: :sftp_toolkit,
      version: "1.0.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "SFTP Client library extensions",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:ssh]
    ]
  end

  defp deps do
    [
      {:bunch, "~> 0.3.0"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Software Mansion"],
      licenses: ["Apache 2.0"],
      files: [
        "lib",
        "mix.exs",
        "README*",
        "LICENSE*",
        ".formatter.exs"
      ],
      links: %{
        "GitHub" => "https://github.com/SoftwareMansion/elixir-sftp-toolkit"
      }
    ]
  end
end
