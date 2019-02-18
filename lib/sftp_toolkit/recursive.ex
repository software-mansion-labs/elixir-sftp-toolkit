defmodule SFTPToolkit.Recursive do
  @moduledoc """
  Module containing functions that allow to do recursive
  operations on the directories.
  """

  @default_operation_timeout 5000

  @doc """
  Recursively creates a directory over existing SFTP channel.

  ## Arguments

  Expects the following arguments:

  * `sftp_channel_pid` - PID of the already opened SFTP channel,
  * `path` - path to create,
  * `options` - additional options, see below.

  ## Options

  * `operation_timeout` - SFTP operation timeout (it is a timeout
     per each SFTP operation, not total timeout), defaults to 5000 ms.

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
  @spec make_dir_recursive(pid, Path.t, [operation_timeout: timeout]) :: :ok | {:error, any}
  def make_dir_recursive(sftp_channel_pid, path, options \\ []) do
    do_make_dir_recursive(sftp_channel_pid, Path.split(path), options, [])
  end

  defp do_make_dir_recursive(_sftp_channel_pid, [], _options, _acc), do: :ok

  defp do_make_dir_recursive(sftp_channel_pid, [head|tail], options, acc) do
    path = Path.join(Enum.reverse([head|acc]))
    case :ssh_sftp.read_file_info(sftp_channel_pid, path, Keyword.get(options, :operation_timeout, @default_operation_timeout)) do
      {:ok, {:file_info, _size, :directory, access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid}} when access in [:write, :read_write] ->
        # Directory already exists and we have right permissions, skip creation
        do_make_dir_recursive(sftp_channel_pid, tail, options, [head|acc])

      {:ok, {:file_info, _size, :directory, access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid}} ->
        # Directory already exists but we have invalid access mode, error
        {:error, {:invalid_access, path, access}}

      {:ok, {:file_info, _size, type, _access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid}} ->
        # Path component already exists but it is not a directory
        {:error, {:invalid_type, path, type}}

      {:error, :no_such_file} ->
        # There's no such directory, try to create it
        case :ssh_sftp.make_dir(sftp_channel_pid, path, Keyword.get(options, :operation_timeout, @default_operation_timeout)) do
          :ok ->
            # We made it, recurse
            do_make_dir_recursive(sftp_channel_pid, tail, options, [head|acc])
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
  * `options` - additional options, see below.

  ## Options

  * `operation_timeout` - SFTP operation timeout (it is a timeout
     per each SFTP operation, not total timeout), defaults to 5000 ms,
  * `included_types` - which file types should be included in the
     result, defaults to `[:regular]`. See the `:file.file_info`
     typespec for list of all valid values,
  * `result_format` - can be one of `:path` or `:file_info`.

     If you pass `:path`, the result will be a list of strings containing
     file names.

     If you pass `:file_info`, the result will be a list of `{path, file_info}`
     tuples, where `file_info` will have have the same format as
     `:file.file_info`. Please note that if you return `:skip_but_include`
     from the `iterate_callback` the `file_info` will be `:undefined`.

     Defaults to `:path`.
  * `recurse_callback` - optional function that will be called
     before recursing to the each subdirectory that is found. It will
     get one argument that is a path currently being evaluated and should
     return one of `:skip`, `:skip_but_include` or `:ok`.

     If it will return `:skip`, the whole tree, including the path passed
     as an argument to the function will be skipped and they won't be
     included in the final result.

     If it will return `:skip_but_include`, the underlying tree, except
     the path passed as an argument to the function will be skipped
     won't be included in the final result but the path itself will,
     as long as it's type is within included_types.

     If it will return `:ok`, it will recurse, and this is also
     the default behaviour if function is not passed.
  * `iterate_callback` - optional function that will be called
     before evaluating each file that is found whether it is a directory.
     It will get one argument that is a path currently being evaluated
     and should return one of `:skip`, `:skip_but_include` or `:ok`.

     If it will return `:skip`, the file will not be evaluated for its
     type and it will not be included in the final result.

     If it will return `:skip_but_include`, the file will not be evaluated
     for its type but it will be always included in the final result.

     If it will return `:ok`, it will evaluate file's type and try recurse
     if it's directory, and this is also the default behaviour if function
     is not passed.

  The `recurse_callback` and `iterate_callback` options are useful if you
  traverse a large tree and you can determine that only certain parts of it
  are meaningful solely from the paths or file names. For example if your
  directories are created programatically, and you know that files with
  the `.pdf` extension are always regular files and by no means they
  are directories you can instruct this function that it's pointless to
  read their file information. Thanks to this you can limit amount of
  calls to `:ssh_sftp.read_file_info/3` just by checking if given path
  has an appropriate suffix and returning the appropriate value.

  ## Limitations

  It will ignore symbolic links. They will not be followed.

  It will ignore directories without proper access and recurse only
  to these that provide at least read access.

  ## Return values

  On success returns `{:ok, list_of_files}`.

  On error returns `{:error, reason}`, where `reason` might be one
  of the following:

  * `{:invalid_type, path, type} - given path is not a directory and
    it's actual type is specified as `type`,
  * `{:invalid_access, path, access}` - given path is a directory, but
    it's access is is invalid and it's actual access mode is specified
    as `access`.
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
  @spec list_dir_recursive(pid, Path.t, [
    operation_timeout: timeout,
    result_format: :path | :file_info,
    included_types: [:device | :directory | :other | :regular | :symlink | :undefined],
    recurse_callback: nil | (Path.t -> :skip | :skip_but_include | :ok),
    iterate_callback: nil | (Path.t -> :skip | :skip_but_include | :ok),
  ]) :: {:ok, [] | [Path.t | {Path.t, :file.file_info}]} | {:error, any}
  def list_dir_recursive(sftp_channel_pid, path \\ "", options \\ []) do
    case :ssh_sftp.read_file_info(sftp_channel_pid, path, Keyword.get(options, :operation_timeout, @default_operation_timeout)) do
      {:ok, {:file_info, _size, :directory, access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid}} when access in [:read, :read_write] ->
        # Given path is a directory and we have right permissions, recurse
        do_list_dir_recursive(sftp_channel_pid, path, options, [])

      {:ok, {:file_info, _size, :directory, access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid}} ->
        # Given path is a directory but we do not have have right permissions, error
        {:error, {:invalid_access, path, access}}

      {:ok, {:file_info, _size, type, _access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid}} ->
        # Given path is not a directory, error
        {:error, {:invalid_type, path, type}}
    end
  end

  defp do_list_dir_recursive(sftp_channel_pid, path, options, acc) do
    case :ssh_sftp.list_dir(sftp_channel_pid, path, Keyword.get(options, :operation_timeout, @default_operation_timeout)) do
      {:ok, files} ->
        case do_list_dir_iterate(sftp_channel_pid, path, files, options, acc) do
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

  defp do_list_dir_iterate(_sftp_channel_pid, _path, [], _options, acc) do
    {:ok, acc}
  end

  defp do_list_dir_iterate(sftp_channel_pid, path, [head|tail], options, acc) when head in ['.', '..'] do
    do_list_dir_iterate(sftp_channel_pid, path, tail, options, acc)
  end

  defp do_list_dir_iterate(sftp_channel_pid, path, [head|tail], options, acc) do
    path_full = Path.join(path, head)
    included_types = Keyword.get(options, :included_types, [:regular])
    iterate_callback = Keyword.get(options, :iterate_callback, nil)
    recurse_callback = Keyword.get(options, :recurse_callback, nil)

    # Call iterate_callback function only once, if it's present and store the return value
    iterate_callback_result = if !is_nil(iterate_callback) do
      iterate_callback.(path_full)
    end

    # If we're allowed to read file info, do this
    if is_nil(iterate_callback) or (!is_nil(iterate_callback) and iterate_callback_result == :ok) do
      case :ssh_sftp.read_file_info(sftp_channel_pid, path_full, Keyword.get(options, :operation_timeout, @default_operation_timeout)) do
        {:ok, {:file_info, _size, :directory, access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid} = file_info} when access in [:read, :read_write] ->
          # Directory already exists and we have right permissions

          # Determine what data should be added to the result
          result_item = case Keyword.get(options, :result_format, :path) do
            :path ->
              path_full
            :file_info ->
              {path_full, file_info}
          end

          # Store it if :directory was listed in the included_types
          acc = if :directory in included_types do
            [result_item|acc]
          else
            acc
          end

          # Call recurse_callback function only once, if it's present and store the return value
          recurse_callback_result = if !is_nil(recurse_callback) do
            recurse_callback.(path_full)
          end

          # If we're allowed to recurse, do this
          if is_nil(recurse_callback) or (!is_nil(recurse_callback) and recurse_callback_result == :ok) do
            case do_list_dir_recursive(sftp_channel_pid, path_full, options, acc) do
              {:ok, acc} ->
                do_list_dir_iterate(sftp_channel_pid, path, tail, options, acc)
              {:error, reason} ->
                {:error, reason}
            end
          else
            # If we're not allowed to recurse, honour instructions received from the recurse_callback function
            case recurse_callback_result do
              :skip_but_include ->
                do_list_dir_iterate(sftp_channel_pid, path, tail, options, [result_item|acc])
              :skip ->
                do_list_dir_iterate(sftp_channel_pid, path, tail, options, acc)
            end
          end

        {:ok, {:file_info, _size, type, access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid} = file_info} when access in [:read, :read_write] ->
          # We found a different file than a directory and it is readable

          # Determine what data should be added to the result
          result_item = case Keyword.get(options, :result_format, :path) do
            :path ->
              path_full
            :file_info ->
              {path_full, file_info}
          end

          # Add it to the result it if its type was listed in the included_typesd
          acc = if type in included_types do
            [result_item|acc]
          else
            acc
          end

          # Proceed
          do_list_dir_iterate(sftp_channel_pid, path, tail, options, acc)

        {:ok, {:file_info, _size, _type, _access, _atime, _mtime, _ctime, _mode, _links, _major_device, _minor_device, _inode, _uid, _gid}} ->
          # We read something but we have no permissions, ignore that
          do_list_dir_iterate(sftp_channel_pid, path, tail, options, acc)

        {:error, reason} ->
          # File info read failed, error
          {:error, {:file_info, reason}}
      end
    else
      # If we're not allowed to read file info, honour instructions received from the iterate_callback function
      case iterate_callback_result do
        :skip_but_include ->
          # Determine what data should be added to the result
          result_item = case Keyword.get(options, :result_format, :path) do
            :path ->
              path_full
            :file_info ->
              # If read_file_info was called the file info is unknown
              {path_full, :unknown}
          end

          do_list_dir_iterate(sftp_channel_pid, path, tail, options, [result_item|acc])
        :skip ->
          do_list_dir_iterate(sftp_channel_pid, path, tail, options, acc)
      end
    end
  end
end
