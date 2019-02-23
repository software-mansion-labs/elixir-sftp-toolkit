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

  describe "del_dir_recursive/2" do
    test "if given path exists and is an empty directory, it returns :ok", %{
      sftp_channel_pid: sftp_channel_pid,
      tempdir: tempdir
    } do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") == :ok
    end

    test "if given path exists and is an empty directory, it removes the directory", %{
      sftp_channel_pid: sftp_channel_pid,
      tempdir: tempdir
    } do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join(tempdir, "testdir1")) == false
      assert Path.join(tempdir, "**") |> Path.wildcard() == []
    end

    test "if given path exists and is an empty directory, it does not remove other directories",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))
      File.mkdir_p!(Path.join(tempdir, "anotherdir"))

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join(tempdir, "anotherdir")) == true
    end

    test "if given path exists and is an empty directory with other empty directories, it returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join([tempdir, "testdir1", "testdir2a"]))
      File.mkdir_p!(Path.join([tempdir, "testdir1", "testdir2b"]))

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") == :ok
    end

    test "if given path exists and is an empty directory with other empty directories, it removes the directory along with subdirectories",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join([tempdir, "testdir1", "testdir2a"]))
      File.mkdir_p!(Path.join([tempdir, "testdir1", "testdir2b"]))

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join([tempdir, "testdir1/testdir2a"])) == false
      assert File.exists?(Path.join([tempdir, "testdir1/testdir2b"])) == false
      assert File.exists?(Path.join(tempdir, "testdir1")) == false
      assert Path.join(tempdir, "**") |> Path.wildcard() == []
    end

    test "if given path exists and is an empty directory with other empty directories of multiple levels, it returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join([tempdir, "testdir1", "testdir2a"]))
      File.mkdir_p!(Path.join([tempdir, "testdir1", "testdir2b"]))
      File.mkdir_p!(Path.join([tempdir, "testdir1", "testdir2c", "testdir3"]))

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") == :ok
    end

    test "if given path exists and is an empty directory with other empty directories of multiple levels, it removes the directory along with subdirectories",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join([tempdir, "testdir1", "testdir2a"]))
      File.mkdir_p!(Path.join([tempdir, "testdir1", "testdir2b"]))
      File.mkdir_p!(Path.join([tempdir, "testdir1", "testdir2c", "testdir3"]))

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join([tempdir, "testdir1/testdir2a"])) == false
      assert File.exists?(Path.join([tempdir, "testdir1/testdir2b"])) == false
      assert File.exists?(Path.join([tempdir, "testdir1/testdir2c/testdir3"])) == false
      assert File.exists?(Path.join([tempdir, "testdir1/testdir2c"])) == false
      assert File.exists?(Path.join(tempdir, "testdir1")) == false
      assert Path.join(tempdir, "**") |> Path.wildcard() == []
    end

    test "if given path exists and is a directory with regular files inside, it returns :ok", %{
      sftp_channel_pid: sftp_channel_pid,
      tempdir: tempdir
    } do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))
      File.write!(Path.join([tempdir, "testdir1", "testfile1"]), "whatever")
      File.write!(Path.join([tempdir, "testdir1", "testfile2"]), "whatever")

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") == :ok
    end

    test "if given path exists and is a directory with regular files inside, it removes the directory with its files",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))
      File.write!(Path.join([tempdir, "testdir1", "testfile1"]), "whatever")
      File.write!(Path.join([tempdir, "testdir1", "testfile2"]), "whatever")

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join(tempdir, "testdir1")) == false
      assert Path.join(tempdir, "**") |> Path.wildcard() == []
    end

    test "if given path exists and is a directory with regular files inside and some subdirectories, it returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))
      File.write!(Path.join([tempdir, "testdir1", "testfile1"]), "whatever")
      File.write!(Path.join([tempdir, "testdir1", "testfile2"]), "whatever")

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") == :ok
    end

    test "if given path exists and is a directory with regular files inside and some subdirectories, it removes the directory with its files",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))
      File.mkdir_p!(Path.join([tempdir, "testdir1", "testdir2"]))
      File.write!(Path.join([tempdir, "testdir1", "testfile1"]), "whatever")
      File.write!(Path.join([tempdir, "testdir1", "testdir2", "testfile2"]), "whatever")

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join(tempdir, "testdir1")) == false
      assert Path.join(tempdir, "**") |> Path.wildcard() == []
    end

    test "if given path does not exist, it returns {:error, {:file_info, path, :no_such_file}}",
         %{sftp_channel_pid: sftp_channel_pid} do
      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") ==
               {:error, {:file_info, "testdir1", :no_such_file}}
    end

    test "if given path exists but it is not a directory, it returns {:error, {:invalid_type, path, type}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.write!(Path.join([tempdir, "testfile1"]), "whatever")

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testfile1") ==
               {:error, {:invalid_type, "testfile1", :regular}}
    end

    test "if given path exists but it is not a directory, it does not delete it", %{
      sftp_channel_pid: sftp_channel_pid,
      tempdir: tempdir
    } do
      File.write!(Path.join([tempdir, "testfile1"]), "whatever")

      Recursive.del_dir_recursive(sftp_channel_pid, "testfile1")

      assert File.exists?(Path.join([tempdir, "testfile1"])) == true

      assert Path.join(tempdir, "**") |> Path.wildcard() == [
               Path.join([tempdir, "testfile1"])
             ]
    end

    test "if given path exists and it is a directory, but it does not have write permissions, it returns {:error, {:invalid_access, path, access}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))
      File.chmod!(Path.join(tempdir, "testdir1"), 0o400)

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") ==
               {:error, {:invalid_access, "testdir1", :read}}
    end

    test "if given path exists and it is a directory, but it does not have write permissions, it does not delete it",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join(tempdir, "testdir1"))
      File.chmod!(Path.join(tempdir, "testdir1"), 0o400)

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join([tempdir, "testdir1"])) == true

      assert Path.join(tempdir, "**") |> Path.wildcard() == [
               Path.join([tempdir, "testdir1"])
             ]
    end
  end
end
