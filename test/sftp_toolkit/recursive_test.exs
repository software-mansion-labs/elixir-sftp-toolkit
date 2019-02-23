defmodule SFTPToolkit.RecursiveTest do
  use ExUnit.Case, async: true
  use SFTPToolkit.Support.SSHDaemon
  alias SFTPToolkit.Recursive

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
      {:ok, %File.Stat{type: type}} = File.stat(Path.join(tempdir, "testdir"))
      assert type == :directory
    end

    test "if given path is valid and contains many levels and there's no file or directory with such name, returns :ok",
         %{sftp_channel_pid: sftp_channel_pid} do
      assert Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2") == :ok
    end

    test "if given path is valid and contains many levels and there's no file or directory with such name, creates multiple directories",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2")

      assert Path.join(tempdir, "**") |> Path.wildcard() == [
               Path.join(tempdir, "testdir1"),
               Path.join([tempdir, "testdir1", "testdir2"])
             ]
      {:ok, %File.Stat{type: type1}} = File.stat(Path.join(tempdir, "testdir1"))
      assert type1 == :directory
      {:ok, %File.Stat{type: type2}} = File.stat(Path.join([tempdir, "testdir1", "testdir2"]))
      assert type2 == :directory
    end

    test "if given path is valid and contains many levels and some levels are already present and they are directories, returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))

      assert Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2") == :ok
    end

    test "if given path is valid and contains many levels and some levels are already present and they are directories, creates missing directories",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))

      Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2")

      assert Path.join(tempdir, "**") |> Path.wildcard() == [
               Path.join(tempdir, "testdir1"),
               Path.join([tempdir, "testdir1", "testdir2"])
             ]
      {:ok, %File.Stat{type: type2}} = File.stat(Path.join([tempdir, "testdir1", "testdir2"]))
      assert type2 == :directory
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
