defmodule RtcServerTest do
  use ExUnit.Case
  doctest RtcServer

  test "greets the world" do
    assert RtcServer.hello() == :world
  end
end
