defmodule SftpToolkitTest do
  use ExUnit.Case
  doctest SftpToolkit

  test "greets the world" do
    assert SftpToolkit.hello() == :world
  end
end
