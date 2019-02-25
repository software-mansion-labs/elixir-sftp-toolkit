defmodule SFTPToolkit.RecursiveTest do
  use ExUnit.Case, async: true
  use SFTPToolkit.Support.SSHDaemon
  alias SFTPToolkit.Recursive

  describe "make_dir_recursive/2" do
    test "if given path is invalid, returns {:error, {:invalid_path, path}}",
         %{sftp_channel_pid: sftp_channel_pid} do
      assert Recursive.make_dir_recursive(sftp_channel_pid, "") == {:error, {:invalid_path, ""}}
    end

    test "if given path is valid and contains just one level and there's no file or directory with such name, returns :ok",
         %{sftp_channel_pid: sftp_channel_pid} do
      assert Recursive.make_dir_recursive(sftp_channel_pid, "testdir") == :ok
    end

    test "if given path is valid and contains just one level and there's no file or directory with such name, creates a single directory",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      Recursive.make_dir_recursive(sftp_channel_pid, "testdir")

      assert Path.join(sftpdir, "**") |> Path.wildcard() == [
               Path.join(sftpdir, "testdir")
             ]

      {:ok, %File.Stat{type: type}} = File.stat(Path.join(sftpdir, "testdir"))
      assert type == :directory
    end

    test "if given path is valid and contains many levels and there's no file or directory with such name, returns :ok",
         %{sftp_channel_pid: sftp_channel_pid} do
      assert Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2") == :ok
    end

    test "if given path is valid and contains many levels and there's no file or directory with such name, creates multiple directories",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2")

      assert Path.join(sftpdir, "**") |> Path.wildcard() == [
               Path.join(sftpdir, "testdir1"),
               Path.join([sftpdir, "testdir1", "testdir2"])
             ]

      {:ok, %File.Stat{type: type1}} = File.stat(Path.join(sftpdir, "testdir1"))
      assert type1 == :directory
      {:ok, %File.Stat{type: type2}} = File.stat(Path.join([sftpdir, "testdir1", "testdir2"]))
      assert type2 == :directory
    end

    test "if given path is valid and contains many levels and some levels are already present and they are directories, returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))

      assert Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2") == :ok
    end

    test "if given path is valid and contains many levels and some levels are already present and they are directories, creates missing directories",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))

      Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2")

      assert Path.join(sftpdir, "**") |> Path.wildcard() == [
               Path.join(sftpdir, "testdir1"),
               Path.join([sftpdir, "testdir1", "testdir2"])
             ]

      {:ok, %File.Stat{type: type2}} = File.stat(Path.join([sftpdir, "testdir1", "testdir2"]))
      assert type2 == :directory
    end

    test "if given path is valid and contains many levels and some levels are already present but they are not directories, returns {:error, {:invalid_type, path, type}}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testdir1"), "whatever")

      assert Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2") ==
               {:error, {:invalid_type, "testdir1", :regular}}
    end

    test "if given path is valid and contains many levels and some levels are already present but they are not directories, does not create a subdirectory",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testdir1"), "whatever")

      Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2")

      assert Path.join(sftpdir, "**") |> Path.wildcard() == [
               Path.join(sftpdir, "testdir1")
             ]
    end

    test "if given path is valid and contains many levels and some levels are already present and they are directories but they have only read permissions, returns {:error, {:invalid_access, path, :read}}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.chmod!(Path.join(sftpdir, "testdir1"), 0o400)

      assert Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2") ==
               {:error, {:invalid_access, "testdir1", :read}}
    end

    test "if given path is valid and contains many levels and some levels are already present and they are directories, but they have only read permissions does not create a subdirectory",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.chmod!(Path.join(sftpdir, "testdir1"), 0o400)

      Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2")

      assert Path.join(sftpdir, "**") |> Path.wildcard() == [
               Path.join(sftpdir, "testdir1")
             ]
    end

    test "if given path is valid and contains many levels and some levels are already present and they are directories but they have no permissions, returns {:error, {:invalid_access, path, :none}}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.chmod!(Path.join(sftpdir, "testdir1"), 0o000)

      assert Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2") ==
               {:error, {:invalid_access, "testdir1", :none}}
    end

    test "if given path is valid and contains many levels and some levels are already present and they are directories, but they have no permissions does not create a subdirectory",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.chmod!(Path.join(sftpdir, "testdir1"), 0o000)

      Recursive.make_dir_recursive(sftp_channel_pid, "testdir1/testdir2")

      assert Path.join(sftpdir, "**") |> Path.wildcard() == [
               Path.join(sftpdir, "testdir1")
             ]
    end
  end

  describe "del_dir_recursive/2" do
    test "if given path exists and is an empty directory, it returns :ok", %{
      sftp_channel_pid: sftp_channel_pid,
      sftpdir: sftpdir
    } do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") == :ok
    end

    test "if given path exists and is an empty directory, it removes the directory", %{
      sftp_channel_pid: sftp_channel_pid,
      sftpdir: sftpdir
    } do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join(sftpdir, "testdir1")) == false
      assert Path.join(sftpdir, "**") |> Path.wildcard() == []
    end

    test "if given path exists and is an empty directory, it does not remove other directories",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.mkdir_p!(Path.join(sftpdir, "anotherdir"))

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join(sftpdir, "anotherdir")) == true
    end

    test "if given path exists and is an empty directory with other empty directories, it returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2a"]))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2b"]))

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") == :ok
    end

    test "if given path exists and is an empty directory with other empty directories, it removes the directory along with subdirectories",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2a"]))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2b"]))

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join([sftpdir, "testdir1/testdir2a"])) == false
      assert File.exists?(Path.join([sftpdir, "testdir1/testdir2b"])) == false
      assert File.exists?(Path.join(sftpdir, "testdir1")) == false
      assert Path.join(sftpdir, "**") |> Path.wildcard() == []
    end

    test "if given path exists and is an empty directory with other empty directories of multiple levels, it returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2a"]))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2b"]))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2c", "testdir3"]))

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") == :ok
    end

    test "if given path exists and is an empty directory with other empty directories of multiple levels, it removes the directory along with subdirectories",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2a"]))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2b"]))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2c", "testdir3"]))

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join([sftpdir, "testdir1/testdir2a"])) == false
      assert File.exists?(Path.join([sftpdir, "testdir1/testdir2b"])) == false
      assert File.exists?(Path.join([sftpdir, "testdir1/testdir2c/testdir3"])) == false
      assert File.exists?(Path.join([sftpdir, "testdir1/testdir2c"])) == false
      assert File.exists?(Path.join(sftpdir, "testdir1")) == false
      assert Path.join(sftpdir, "**") |> Path.wildcard() == []
    end

    test "if given path exists and is a directory with regular files inside, it returns :ok", %{
      sftp_channel_pid: sftp_channel_pid,
      sftpdir: sftpdir
    } do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.write!(Path.join([sftpdir, "testdir1", "testfile1"]), "whatever")
      File.write!(Path.join([sftpdir, "testdir1", "testfile2"]), "whatever")

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") == :ok
    end

    test "if given path exists and is a directory with regular files inside, it removes the directory with its files",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.write!(Path.join([sftpdir, "testdir1", "testfile1"]), "whatever")
      File.write!(Path.join([sftpdir, "testdir1", "testfile2"]), "whatever")

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join(sftpdir, "testdir1")) == false
      assert Path.join(sftpdir, "**") |> Path.wildcard() == []
    end

    test "if given path exists and is a directory with regular files inside and some subdirectories, it returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.write!(Path.join([sftpdir, "testdir1", "testfile1"]), "whatever")
      File.write!(Path.join([sftpdir, "testdir1", "testfile2"]), "whatever")

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") == :ok
    end

    test "if given path exists and is a directory with regular files inside and some subdirectories, it removes the directory with its files",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2"]))
      File.write!(Path.join([sftpdir, "testdir1", "testfile1"]), "whatever")
      File.write!(Path.join([sftpdir, "testdir1", "testdir2", "testfile2"]), "whatever")

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join(sftpdir, "testdir1")) == false
      assert Path.join(sftpdir, "**") |> Path.wildcard() == []
    end

    test "if given path does not exist, it returns {:error, {:file_info, path, :no_such_file}}",
         %{sftp_channel_pid: sftp_channel_pid} do
      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") ==
               {:error, {:file_info, "testdir1", :no_such_file}}
    end

    test "if given path exists but it is not a directory but a regular file, it returns {:error, {:invalid_type, path, :regular}}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.write!(Path.join([sftpdir, "testfile1"]), "whatever")

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testfile1") ==
               {:error, {:invalid_type, "testfile1", :regular}}
    end

    test "if given path exists but it is not a directory but a regular file, it does not delete it",
         %{
           sftp_channel_pid: sftp_channel_pid,
           sftpdir: sftpdir
         } do
      File.write!(Path.join([sftpdir, "testfile1"]), "whatever")

      Recursive.del_dir_recursive(sftp_channel_pid, "testfile1")

      assert File.exists?(Path.join([sftpdir, "testfile1"])) == true

      assert Path.join(sftpdir, "**") |> Path.wildcard() == [
               Path.join([sftpdir, "testfile1"])
             ]
    end

    test "if given path exists but it is not a directory but a symlink, it returns {:error, {:invalid_type, path, :regular}}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.write!(Path.join([sftpdir, "testfile1"]), "whatever")
      File.ln_s!(Path.join([sftpdir, "testfile1"]), Path.join([sftpdir, "testlink1"]))

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testlink1") ==
               {:error, {:invalid_type, "testlink1", :regular}}
    end

    test "if given path exists but it is not a directory but a symlink, it does not delete it", %{
      sftp_channel_pid: sftp_channel_pid,
      sftpdir: sftpdir
    } do
      File.write!(Path.join([sftpdir, "testfile1"]), "whatever")
      File.ln_s!(Path.join([sftpdir, "testfile1"]), Path.join([sftpdir, "testlink1"]))

      Recursive.del_dir_recursive(sftp_channel_pid, "testlink1")

      assert File.exists?(Path.join([sftpdir, "testfile1"])) == true
      assert File.exists?(Path.join([sftpdir, "testlink1"])) == true

      assert Path.join(sftpdir, "**") |> Path.wildcard() == [
               Path.join([sftpdir, "testfile1"]),
               Path.join([sftpdir, "testlink1"])
             ]
    end

    test "if given path exists and it is a directory, but it does not have write permissions, it returns {:error, {:invalid_access, path, access}}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.chmod!(Path.join(sftpdir, "testdir1"), 0o400)

      assert Recursive.del_dir_recursive(sftp_channel_pid, "testdir1") ==
               {:error, {:invalid_access, "testdir1", :read}}
    end

    test "if given path exists and it is a directory, but it does not have write permissions, it does not delete it",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.chmod!(Path.join(sftpdir, "testdir1"), 0o400)

      Recursive.del_dir_recursive(sftp_channel_pid, "testdir1")

      assert File.exists?(Path.join([sftpdir, "testdir1"])) == true

      assert Path.join(sftpdir, "**") |> Path.wildcard() == [
               Path.join([sftpdir, "testdir1"])
             ]
    end
  end

  describe "list_dir_recursive/1" do
    test "if there are neither subdirectories nor files, it returns {:ok, []}",
         %{sftp_channel_pid: sftp_channel_pid} do
      assert Recursive.list_dir_recursive(sftp_channel_pid) == {:ok, []}
    end

    test "if there are only some subdirectories, it returns {:ok, []}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2"]))

      assert Recursive.list_dir_recursive(sftp_channel_pid) == {:ok, []}
    end

    test "if there are some subdirectories and files, it returns {:ok, list_of_regular_files}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2"]))
      File.write!(Path.join([sftpdir, "testdir1", "testfile1"]), "whatever")
      File.write!(Path.join([sftpdir, "testdir1", "testdir2", "testfile2"]), "whatever")

      assert Recursive.list_dir_recursive(sftp_channel_pid) ==
               {:ok,
                [
                  "testdir1/testfile1",
                  "testdir1/testdir2/testfile2"
                ]}
    end
  end

  describe "list_dir_recursive/2" do
    test "if given path is valid and there are neither subdirectories nor files, it returns {:ok, []}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))

      assert Recursive.list_dir_recursive(sftp_channel_pid, "testdir1") == {:ok, []}
    end

    test "if given path is valid and there are only some subdirectories, it returns {:ok, []}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))

      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2"]))

      assert Recursive.list_dir_recursive(sftp_channel_pid, "testdir1") == {:ok, []}
    end

    test "if given path is valid and there are some subdirectories and files, it returns {:ok, list_of_regular_files}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))

      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2"]))
      File.write!(Path.join([sftpdir, "testdir1", "testfile1"]), "whatever")
      File.write!(Path.join([sftpdir, "testdir1", "testdir2", "testfile2"]), "whatever")

      assert Recursive.list_dir_recursive(sftp_channel_pid, "testdir1") ==
               {:ok,
                [
                  "testdir1/testfile1",
                  "testdir1/testdir2/testfile2"
                ]}

      assert Recursive.list_dir_recursive(sftp_channel_pid, "testdir1/testdir2") ==
               {:ok,
                [
                  "testdir1/testdir2/testfile2"
                ]}
    end

    test "if given path does not exist, it returns {:error, {:file_info, path, :no_such_file}}",
         %{sftp_channel_pid: sftp_channel_pid} do
      assert Recursive.list_dir_recursive(sftp_channel_pid, "testdir1") ==
               {:error, {:file_info, "testdir1", :no_such_file}}
    end

    test "if given path is valid and there are some subdirectories and files, but some of them have no permissions, it returns {:ok, list_of_regular_files} but skips contents of directories that are not accessible",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))

      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2a"]))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2b"]))
      File.write!(Path.join([sftpdir, "testdir1", "testfile1"]), "whatever")
      File.write!(Path.join([sftpdir, "testdir1", "testdir2a", "testfile2"]), "whatever")
      File.write!(Path.join([sftpdir, "testdir1", "testdir2b", "testfile3"]), "whatever")
      File.chmod!(Path.join([sftpdir, "testdir1", "testdir2b"]), 0o100)

      assert Recursive.list_dir_recursive(sftp_channel_pid, "testdir1") ==
               {:ok,
                [
                  "testdir1/testfile1",
                  "testdir1/testdir2a/testfile2"
                ]}

      assert Recursive.list_dir_recursive(sftp_channel_pid, "testdir1/testdir2a") ==
               {:ok,
                [
                  "testdir1/testdir2a/testfile2"
                ]}
    end

    test "if given path is valid and there are some subdirectories and files, but some of them have just write permissions, it returns {:ok, list_of_regular_files} but skips contents of directories that are not accessible",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))

      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2a"]))
      File.mkdir_p!(Path.join([sftpdir, "testdir1", "testdir2b"]))
      File.write!(Path.join([sftpdir, "testdir1", "testfile1"]), "whatever")
      File.write!(Path.join([sftpdir, "testdir1", "testdir2a", "testfile2"]), "whatever")
      File.write!(Path.join([sftpdir, "testdir1", "testdir2b", "testfile3"]), "whatever")
      File.chmod!(Path.join([sftpdir, "testdir1", "testdir2b"]), 0o300)

      assert Recursive.list_dir_recursive(sftp_channel_pid, "testdir1") ==
               {:ok,
                [
                  "testdir1/testfile1",
                  "testdir1/testdir2a/testfile2"
                ]}

      assert Recursive.list_dir_recursive(sftp_channel_pid, "testdir1/testdir2a") ==
               {:ok,
                [
                  "testdir1/testdir2a/testfile2"
                ]}
    end

    test "if given path is valid and it is a directory but it has no permissions, returns {:error, {:invalid_access, path, :none}}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.chmod!(Path.join(sftpdir, "testdir1"), 0o100)

      assert Recursive.list_dir_recursive(sftp_channel_pid, "testdir1") ==
               {:error, {:invalid_access, "testdir1", :none}}
    end

    test "if given path is valid and it is a directory but it only has write permissions, returns {:error, {:invalid_access, path, :write}}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir1"))
      File.chmod!(Path.join(sftpdir, "testdir1"), 0o300)

      assert Recursive.list_dir_recursive(sftp_channel_pid, "testdir1") ==
               {:error, {:invalid_access, "testdir1", :write}}
    end

    test "if given path is valid but it is a regular file, returns {:error, {:invalid_type, path, :regular}}",
         %{sftp_channel_pid: sftp_channel_pid, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testdir1"), "whatever")

      assert Recursive.list_dir_recursive(sftp_channel_pid, "testdir1") ==
               {:error, {:invalid_type, "testdir1", :regular}}
    end
  end
end
