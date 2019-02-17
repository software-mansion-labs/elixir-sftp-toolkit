defmodule SFTPToolkit.Recursive do
  @moduledoc """
  Module containing functions that allow to do recursive 
  operations on the directories.  
  """

  @doc """
  Recursively creates a directory over existing SFTP channel.

  Expects the following arguments:

  * `sftp_channel_pid` - PID of the already opened SFTP channel,
  * `path` - path to create,
  * `timeout` - SFTP operation timeout (it is a timeout per each
     SFTP operation, not total timeout), defaults to 5000.

  If we're using SFTP version 3 we get just `:failure` when trying
  to create a directory that already exists, so we have no clear
  error code to distinguish a real error from a case where directory
  just exists and we can proceed.

  Moreover, the path may exist but it can be a regular file which
  will prevent us from creating a subdirectory. 

  Due to these limitations we're checking if directory exists
  prior to each creation of a directory as we can't rely on the
  error reasons, even if we use newer versions of SFTP they tend to
  return more fine-grained reasons.

  On success returns `:ok`.

  On error returns `{:error, reason}`, where `reason` might have
  the following syntax:

  * `{:make_dir, info}` - `:ssh_sftp.make_dir/3` failed and `info`
    contains the underlying error returned from it,
  * `{:file_info, info}` - `:ssh_sftp.read_file_info/3` failed and 
    `info` contains the underlying error returned from it,
  * `{:invalid_type, path, type} - one of the components of the
    path to create, specified as `path` is not a directory, and
    it's actual type is specified as `type`,
  * `{:invalid_access, path, access}` - one of the components of 
    the path to create, specified as `path` is a directory, but
    it's access is is invalid and it's actual access mode is 
    specified as `access`.
  """
  @spec make_dir_recursive(pid, Path.t, timeout) :: :ok | {:error, any}
  def make_dir_recursive(sftp_channel_pid, path, timeout \\ 5000) do
    do_make_dir_recursive(sftp_channel_pid, Path.split(path), timeout, [])
  end

  defp do_make_dir_recursive(_sftp_channel_pid, [], _timeout, _acc), do: :ok

  defp do_make_dir_recursive(sftp_channel_pid, [head|tail], timeout, acc) do
    path = Path.join(Enum.reverse([head|acc]))
    case :ssh_sftp.read_file_info(sftp_channel_pid, path, timeout) do
      {:ok, {:file_info, _size, :directory, access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid}} when access in [:write, :read_write] ->
        # Directory already exists and we have right permissions, skip creation
        do_make_dir_recursive(sftp_channel_pid, tail, timeout, [head|acc])

      {:ok, {:file_info, _size, :directory, access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid}} ->
        # Directory already exists but we have invalid access mode, error
        {:error, {:invalid_access, path, access}}

      {:ok, {:file_info, _size, type, _access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid}} ->
        # Path component already exists but it is not a directory
        {:error, {:invalid_type, path, type}}

      {:error, :no_such_file} ->
        # There's no such directory, try to create it
        case :ssh_sftp.make_dir(sftp_channel_pid, path, timeout) do
          :ok ->
            do_make_dir_recursive(sftp_channel_pid, tail, timeout, [head|acc])
          {:error, reason} ->
            {:error, {:make_dir, reason}}
        end

      {:error, other} ->
        # File info read failed, error
        {:error, {:file_info, other}}
    end
  end

end