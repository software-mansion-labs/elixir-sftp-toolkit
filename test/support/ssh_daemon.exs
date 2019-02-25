defmodule SFTPToolkit.Support.SSHDaemon do
  def make_tempdir do
    tempdir =
      cond do
        !is_nil(System.get_env("TMPDIR")) ->
          System.get_env("TMPDIR")

        !is_nil(System.get_env("TMP")) ->
          System.get_env("TMP")

        !is_nil(System.get_env("TEMP")) ->
          System.get_env("TEMP")

        true ->
          "/tmp"
      end
      |> Path.join("sftp_toolkit_test")
      |> Path.join(to_string(Enum.random(1_000_000..9_999_999)))

    if File.exists?(tempdir) do
      make_tempdir()
    else
      {:ok, tempdir}
    end
  end

  defmacro __using__([]) do
    quote do
      setup do
        {:ok, tempdir} = SFTPToolkit.Support.SSHDaemon.make_tempdir()
        {:ok, sftpdir} = SFTPToolkit.Support.SSHDaemon.make_tempdir()

        :ok = File.mkdir_p!(tempdir)
        :ok = File.mkdir_p!(sftpdir)

        {:ok, daemon_ref} =
          {:ok, ssh_daemon_ref} =
          :ssh.daemon(:loopback, 0,
            user_passwords: [{'someuser', 'somepassword'}],
            system_dir: Path.join([System.cwd!(), "test", "extra", "ssh"]) |> to_charlist,
            subsystems: [
              :ssh_sftpd.subsystem_spec(cwd: sftpdir |> to_charlist)
            ]
          )

        {:ok, [port: port, ip: ip, profile: :default]} = :ssh.daemon_info(daemon_ref)

        {:ok, sftp_channel_pid, ssh_connection_ref} =
          :ssh_sftp.start_channel(ip, port,
            user: 'someuser',
            password: 'somepassword',
            user_interaction: false,
            silently_accept_hosts: true
          )

        on_exit(:ssh_client, fn ->
          :ssh.close(ssh_connection_ref)
        end)

        on_exit(:ssh_daemon, fn ->
          :ssh.stop_daemon(ssh_daemon_ref)
        end)

        on_exit(:del, fn ->
          # Some files created in the tests can have chmod 0o000, we need
          # to fix that prior to removal
          Path.wildcard(Path.join(sftpdir, "**"))
          |> Enum.each(fn path ->
            File.chmod!(path, 0o700)
          end)

          File.rm_rf!(sftpdir)

          # Some files created in the tests can have chmod 0o000, we need
          # to fix that prior to removal
          Path.wildcard(Path.join(tempdir, "**"))
          |> Enum.each(fn path ->
            File.chmod!(path, 0o700)
          end)

          File.rm_rf!(tempdir)
        end)

        [sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir, tempdir: tempdir]
      end
    end
  end
end
