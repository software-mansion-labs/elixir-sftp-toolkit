defmodule SFTPToolkit.UploadTest do
  use ExUnit.Case, async: true
  use SFTPToolkit.Support.SSHDaemon
  alias SFTPToolkit.Upload

  describe "upload_file/3" do
    test "if given local file does not exist, returns {:error, {:local_open, :enoent}}",
         %{sftp_channel_pid: sftp_channel_pid} do
      assert Upload.upload_file(sftp_channel_pid, "whatever", "whatever") ==
               {:error, {:local_open, :enoent}}
    end

    test "if given local file exists but have no permissions, returns {:error, {:local_open, :enoent}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.write!(Path.join(tempdir, "testfile"), "whatever")
      File.chmod!(Path.join(tempdir, "testfile"), 0o000)

      assert Upload.upload_file(sftp_channel_pid, Path.join(tempdir, "testfile"), "testfile") ==
               {:error, {:local_open, :eacces}}
    end

    test "if given local file exists but have just write permissions, returns {:error, {:local_open, :enoent}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.write!(Path.join(tempdir, "testfile"), "whatever")
      File.chmod!(Path.join(tempdir, "testfile"), 0o200)

      assert Upload.upload_file(sftp_channel_pid, Path.join(tempdir, "testfile"), "testfile") ==
               {:error, {:local_open, :eacces}}
    end

    test "if given local file exists but have just execute permissions, returns {:error, {:local_open, :enoent}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.write!(Path.join(tempdir, "testfile"), "whatever")
      File.chmod!(Path.join(tempdir, "testfile"), 0o100)

      assert Upload.upload_file(sftp_channel_pid, Path.join(tempdir, "testfile"), "testfile") ==
               {:error, {:local_open, :eacces}}
    end

    test "if given local file exists but remote directory to upload has only read permissions, returns {:error, {:remote_open, :permission_denied}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(tempdir, "testfile"), "whatever")

      File.mkdir_p!(Path.join(sftpdir, "testdir"))
      File.chmod!(Path.join(sftpdir, "testdir"), 0o500)

      assert Upload.upload_file(
               sftp_channel_pid,
               Path.join(tempdir, "testfile"),
               "testdir/testfile"
             ) == {:error, {:remote_open, :permission_denied}}
    end

    test "if given local path exists but it is a directory, returns {:error, {:local_open, :eisdir}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.mkdir_p!(Path.join(tempdir, "testdir"))

      assert Upload.upload_file(sftp_channel_pid, Path.join(tempdir, "testdir"), "testdir") ==
               {:error, {:local_open, :eisdir}}
    end

    test "if given local file exists but remote path is already present and it is a directory, returns {:error, {:remote_open, :failure}}",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(tempdir, "testfile"), "whatever")

      File.mkdir_p!(Path.join(sftpdir, "testdir"))

      assert Upload.upload_file(sftp_channel_pid, Path.join(tempdir, "testfile"), "testdir") ==
               {:error, {:remote_open, :failure}}
    end

    test "if given local file exists but remote path is already present and it is a regular file, returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "old")

      File.write!(Path.join(tempdir, "testfile"), "new")

      assert Upload.upload_file(sftp_channel_pid, Path.join(tempdir, "testfile"), "testfile") ==
               :ok
    end

    test "if given local file exists but remote path is already present and it is a regular file, it overrides the existing file",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(sftpdir, "testfile"), "old")

      File.write!(Path.join(tempdir, "testfile"), "new")

      Upload.upload_file(sftp_channel_pid, Path.join(tempdir, "testfile"), "testfile")

      assert File.read!(Path.join(sftpdir, "testfile")) == "new"
    end

    test "if given local file exists and remote path is nopt present, it returns :ok",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir} do
      File.write!(Path.join(tempdir, "testfile"), "new")

      assert Upload.upload_file(sftp_channel_pid, Path.join(tempdir, "testfile"), "testfile") ==
               :ok
    end

    test "if given local file exists and remote path is nopt present, it creates the new file",
         %{sftp_channel_pid: sftp_channel_pid, tempdir: tempdir, sftpdir: sftpdir} do
      File.write!(Path.join(tempdir, "testfile"), "new")

      Upload.upload_file(sftp_channel_pid, Path.join(tempdir, "testfile"), "testfile")

      assert File.read!(Path.join(sftpdir, "testfile")) == "new"
    end
  end
end
