defmodule SFTPToolkit.Recursive do
  @moduledoc """
  Module containing functions that allow to do recursive 
  operations on the directories.  
  """

  @doc """
  Recursively creates a directory over existing SFTP channel.

  ## Arguments

  Expects the following arguments:

  * `sftp_channel_pid` - PID of the already opened SFTP channel,
  * `path` - path to create,
  * `timeout` - SFTP operation timeout (it is a timeout per each
     SFTP operation, not total timeout), defaults to 5000 ms.

  ## Limitations

  This function will not follow symbolic links. If it is going
  to encounter a symbolic link while evaluating existing path
  components, even if it points to a directory, it will return
  an error.

  ## Return values

  On success returns `:ok`.

  On error returns `{:error, reason}`, where `reason` might be one
  of the following:

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

  ## Notes 

  ### Implementation details

  If we're using SFTP version 3 we get just `:failure` when trying
  to create a directory that already exists, so we have no clear
  error code to distinguish a real error from a case where directory
  just exists and we can proceed.

  Moreover, the path component may exist but it can be a regular file 
  which will prevent us from creating a subdirectory. 

  Due to these limitations we're checking if directory exists
  prior to each creation of a directory as we can't rely on the
  returned error reasons, even if we use newer versions of SFTP they 
  tend to return more fine-grained information.

  ### Timeouts

  It was observed in the wild that underlying `:ssh_sftp.list_dir/3`
  and `:ssh_sftp.read_file_info/3` always returned `{:error, :timeout}` 
  with some servers when SFTP version being used was greater than 3,
  at least with Elixir 1.7.4 and Erlang 21.0. If you encounter such 
  issues try passing `{:sftp_vsn, 3}` option while creating a SFTP 
  channel.
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
            # We made it, recurse
            do_make_dir_recursive(sftp_channel_pid, tail, timeout, [head|acc])
          {:error, reason} ->
            # Directory creation failed, error
            {:error, {:make_dir, reason}}
        end

      {:error, other} ->
        # File info read failed, error
        {:error, {:file_info, other}}
    end
  end

  
  @doc """
  Recursively lists files in a given directory over existing SFTP 
  channel.

  ## Arguments

  Expects the following arguments:

  * `sftp_channel_pid` - PID of already opened SFTP channel,
  * `path` - path to list, defaults to empty string,
  * `timeout` - SFTP operation timeout (it is a timeout per each
     SFTP operation, not total timeout), defaults to 5000 ms.

  ## Limitations

  It will take under consideration only directories and regular files. 
  Device files, symbolic links and other types will be ignored.

  It will ignore directories without proper access and recurse only
  to these that provide at least read access.

  ## Return values

  On success returns `{:ok, list_of_files}`.

  On error returns `{:error, reason}`, where `reason` might be one
  of the following:
  
  * `{:list_dir, info}` - `:ssh_sftp.list_dir/3` failed and `info`
    contains the underlying error returned from it,
  * `{:file_info, info}` - `:ssh_sftp.read_file_info/3` failed and 
    `info` contains the underlying error returned from it.

  ## Notes 

  ### Timeouts

  It was observed in the wild that underlying `:ssh_sftp.list_dir/3`
  and `:ssh_sftp.read_file_info/3` always returned `{:error, :timeout}` 
  with some servers when SFTP version being used was greater than 3,
  at least with Elixir 1.7.4 and Erlang 21.0. If you encounter such 
  issues try passing `{:sftp_vsn, 3}` option while creating a SFTP 
  channel.
  """
  @spec list_dir_recursive(pid, Path.t, timeout) :: {:ok, [] | [String.t]} | {:error, any}
  def list_dir_recursive(sftp_channel_pid, path \\ "", timeout \\ 5000) do
    do_list_dir_recursive(sftp_channel_pid, path, timeout, [])
  end

  defp do_list_dir_recursive(sftp_channel_pid, path, timeout, acc) do
    case :ssh_sftp.list_dir(sftp_channel_pid, path, timeout) do
      {:ok, files} ->
        case do_list_dir_iterate(sftp_channel_pid, path, files, timeout, acc) do
          {:ok, files} ->
            {:ok, files}
          {:error, reason} ->
            {:error, reason}
        end
      {:error, reason} ->
        # List dir failed, error
        {:error, {:list_dir, reason}}
    end
  end

  defp do_list_dir_iterate(_sftp_channel_pid, _path, [], _timeout, acc) do
    {:ok, acc}
  end

  defp do_list_dir_iterate(sftp_channel_pid, path, [head|tail], timeout, acc) when head in ['.', '..'] do
    do_list_dir_iterate(sftp_channel_pid, path, tail, timeout, acc)
  end

  defp do_list_dir_iterate(sftp_channel_pid, path, [head|tail], timeout, acc) do
    path_full = Path.join(path, head)
    case :ssh_sftp.read_file_info(sftp_channel_pid, path_full, timeout) do
      {:ok, {:file_info, _size, :directory, access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid}} when access in [:read, :read_write] ->
        # Directory already exists and we have right permissions, recurse
        {:ok, recursed_acc} = do_list_dir_recursive(sftp_channel_pid, path_full, timeout, acc)
        do_list_dir_iterate(sftp_channel_pid, path, tail, timeout, recursed_acc)

      {:ok, {:file_info, _size, :regular, _access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid}} ->
        # We found a file, store it and proceed
        do_list_dir_iterate(sftp_channel_pid, path, tail, timeout, [path_full|acc])

      {:ok, {:file_info, _size, _type, _access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid}} ->
        # We found something else than directory or file, ignore it and proceed
        do_list_dir_iterate(sftp_channel_pid, path, tail, timeout, acc)

      {:error, reason} ->
        # File info read failed, error
        {:error, {:file_info, reason}}
    end
  end  
end