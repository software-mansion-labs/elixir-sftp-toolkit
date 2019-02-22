defmodule SFTPToolkit.RecursiveTest do
  use ExUnit.Case, async: true
  alias SFTPToolkit.Recursive

  setup do
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

    # TODO repeat instead of throw
    if File.exists?(tempdir), do: throw(:tempdir_exist)

    :ok = File.mkdir_p!(tempdir)

    {:ok, daemon_ref} =
      :ssh.daemon(:loopback, 0,
        user_passwords: [{'someuser', 'somepassword'}],
        system_dir: Path.join([System.cwd!(), "test", "extra", "ssh"]) |> to_charlist,
        subsystems: [
          :ssh_sftpd.subsystem_spec(cwd: tempdir |> to_charlist)
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

    on_exit(:ssh, fn ->
      :ssh.close(ssh_connection_ref)
    end)

    on_exit(:del, fn ->
      File.rm_rf!(tempdir)
    end)

    [sftp_channel_pid: sftp_channel_pid, tempdir: tempdir]
  end

  describe "make_dir_recursive/2" do
    test "if given path is valid and contains just one level and there's no file or directory with such name, returns :ok",
         %{sftp_channel_pid: sftp_channel_pid} do
      assert Recursive.make_dir_recursive(sftp_channel_pid, "testdir") == :ok
    end

    test "if given path is valid and contains just one level and there's no file or directory with such name, creates a single directory",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      Recursive.make_dir_recursive(sftp_channel_pid, "testdir")

      assert Path.join(tempdir, "**") |> Path.wildcard() == [
               Path.join(tempdir, "testdir")
             ]
    end

    test "if given path is valid and contains many levels and there's no file or directory with such name, returns :ok",
         %{sftp_channel_pid: sftp_channel_pid} do
      assert Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2") == :ok
    end

    test "if given path is valid and contains many levels and there's no file or directory with such name, creates a single directory",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2")

      assert Path.join(tempdir, "**") |> Path.wildcard() == [
               Path.join(tempdir, "testdir1"),
               Path.join([tempdir, "testdir1", "testdir2"])
             ]
    end

    test "if given path is valid and contains many levels and some levels are already present and they are directories, returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))

      assert Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2") == :ok
    end

    test "if given path is valid and contains many levels and some levels are already present and they are directories, creates a single directory",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))

      Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2")

      assert Path.join(tempdir, "**") |> Path.wildcard() == [
               Path.join(tempdir, "testdir1"),
               Path.join([tempdir, "testdir1", "testdir2"])
             ]
    end

    test "if given path is valid and contains many levels and some levels are already present but they are not directories, returns {:error, {:invalid_type, path, type}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.write!(Path.join(tempdir, "testdir1"), "whatever")

      assert Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2") ==
               {:error, {:invalid_type, "testdir1", :regular}}
    end

    test "if given path is valid and contains many levels and some levels are already present but they are not directories, does not create a subdirectory",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.write!(Path.join(tempdir, "testdir1"), "whatever")

      Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2")

      assert Path.join(tempdir, "**") |> Path.wildcard() == [
               Path.join(tempdir, "testdir1")
             ]
    end

    test "if given path is valid and contains many levels and some levels are already present and they are directories but they don't have write permissions, returns {:error, {:invalid_access, path, access}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))
      File.chmod!(Path.join(tempdir, "testdir1"), 0o400)

      assert Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2") ==
               {:error, {:invalid_access, "testdir1", :read}}
    end

    test "if given path is valid and contains many levels and some levels are already present and they are directories, but they don't have write permissions does not create a subdirectory",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))
      File.chmod!(Path.join(tempdir, "testdir1"), 0o400)

      Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2")

      assert Path.join(tempdir, "**") |> Path.wildcard() == [
               Path.join(tempdir, "testdir1")
             ]
    end
  end
end
