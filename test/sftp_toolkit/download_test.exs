defmodule SFTPToolkit.DownloadTest do
  use ExUnit.Case, async: true
  use SFTPToolkit.Support.SSHDaemon
  alias SFTPToolkit.Download

  describe "download_file/3" do
    test "if given remote file does not exist, returns {:error, {:remote_open, :enoent}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      assert Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile")) ==
               {:error, {:remote_open, :no_such_file}}
    end

    test "if given remote file does not exist, it does not create a file under local path",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile"))

      assert File.exists?(Path.join(tempdir, "testfile")) == false
    end

    test "if given remote file exists and is a regular file but have no permissions, returns {:error, {:remote_open, :permission_denied}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "whatever")
      File.chmod!(Path.join(sftpdir, "testfile"), 0o000)

      assert Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile")) ==
               {:error, {:remote_open, :permission_denied}}
    end

    test "if given remote file exists and is a regular file but have no permissions, it does not create a file under local path",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "whatever")
      File.chmod!(Path.join(sftpdir, "testfile"), 0o000)

      Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile"))

      assert File.exists?(Path.join(tempdir, "testfile")) == false
    end

    test "if given remote file exists and is a regular file but has just write permissions, returns {:error, {:remote_open, :permission_denied}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "whatever")
      File.chmod!(Path.join(sftpdir, "testfile"), 0o200)

      assert Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile")) ==
               {:error, {:remote_open, :permission_denied}}
    end

    test "if given remote file exists and is a regular file but has just write permissions, it does not create a file under local path",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "whatever")
      File.chmod!(Path.join(sftpdir, "testfile"), 0o200)

      Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile"))

      assert File.exists?(Path.join(tempdir, "testfile")) == false
    end

    test "if given remote file exists and is a regular file but has just execute permissions, returns {:error, {:remote_open, :permission_denied}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "whatever")
      File.chmod!(Path.join(sftpdir, "testfile"), 0o100)

      assert Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile")) ==
               {:error, {:remote_open, :permission_denied}}
    end

    test "if given remote file exists and is a regular file but has just execute permissions, it does not create a file under local path",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "whatever")
      File.chmod!(Path.join(sftpdir, "testfile"), 0o100)

      Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile"))

      assert File.exists?(Path.join(tempdir, "testfile")) == false
    end

    test "if given remote file exists but local directory to download has only read permissions, returns {:error, {:local_open, :eacces}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "whatever")

      File.mkdir_p!(Path.join(tempdir, "testdir"))
      File.chmod!(Path.join(tempdir, "testdir"), 0o500)

      assert Download.download_file(
               sftp_channel_pid,
               "testfile",
               Path.join([tempdir, "testdir", "testfile"])
             ) == {:error, {:local_open, :eacces}}
    end

    test "if given remote file exists but local directory to download has only read permissions, it does not create a file under local path",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "whatever")

      File.mkdir_p!(Path.join(tempdir, "testdir"))
      File.chmod!(Path.join(tempdir, "testdir"), 0o500)

      Download.download_file(
        sftp_channel_pid,
        "testfile",
        Path.join([tempdir, "testdir", "testfile"])
      )

      assert File.exists?(Path.join([tempdir, "testdir", "testfile"])) == false
    end

    test "if given local path exists but it is a directory, returns {:error, {:local_open, :eisdir}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "whatever")

      File.mkdir_p!(Path.join(tempdir, "testdir"))

      assert Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testdir")) ==
               {:error, {:local_open, :eisdir}}
    end

    test "if given local path exists but it is a directory, does not change type of the local path",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "whatever")

      File.mkdir_p!(Path.join(tempdir, "testdir"))

      Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testdir"))
      {:ok, %File.Stat{type: type}} = File.stat(Path.join(tempdir, "testdir"))
      assert type == :directory
    end

    test "if remote path is already present and it is a directory, returns {:error, {:remote_open, :failure}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir"))

      assert Download.download_file(sftp_channel_pid, "testdir", Path.join(tempdir, "testfile")) ==
               {:error, {:remote_open, :failure}}
    end

    test "if remote path is already present and it is a directory, it does not create a file under local path",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.mkdir_p!(Path.join(sftpdir, "testdir"))

      Download.download_file(sftp_channel_pid, "testdir", Path.join(tempdir, "testfile"))

      assert File.exists?(Path.join(tempdir, "testfile")) == false
    end

    test "if given remote file exists, and it is not empty, and smaller than the default chunk size, and local path is already present and it is a regular file, returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "new")

      File.write!(Path.join(tempdir, "testfile"), "old")

      assert Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile")) ==
               :ok
    end

    test "if given remote file exists, and it is not empty, and smaller than the default chunk size, and local path is already present and it is a regular file, it overrides the local file",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "new")

      File.write!(Path.join(tempdir, "testfile"), "old")

      Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile"))

      assert File.read!(Path.join(tempdir, "testfile")) == "new"
    end

    test "if given remote file exists, and it is not empty, and smaller than the default chunk size, and local file is not present, returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "new")

      assert Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile")) ==
               :ok
    end

    test "if given remote file exists, and it is not empty, and smaller than the default chunk size, and local file is not present, it creates the local file",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "new")

      Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile"))

      assert File.read!(Path.join(tempdir, "testfile")) == "new"
    end

    test "if given remote file exists, and it is empty, and local file is not present, returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "")

      assert Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile")) ==
               :ok
    end

    test "if given remote file exists, and it is empty, and local file is not present, it creates the local file",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "")

      Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile"))

      assert File.read!(Path.join(tempdir, "testfile")) == ""
    end

    test "if given remote file exists, and it is larger than the default chunk size, and local file is not present, returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), String.duplicate("X", 65_535))

      assert Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile")) ==
               :ok
    end

    test "if given remote file exists, and it is larger than the default chunk size, and local file is not present, it creates the local file",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), String.duplicate("X", 65_535))

      Download.download_file(sftp_channel_pid, "testfile", Path.join(tempdir, "testfile"))

      assert File.read!(Path.join(tempdir, "testfile")) == String.duplicate("X", 65_535)
    end
  end
end
