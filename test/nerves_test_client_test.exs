defmodule NervesTestClientTest do
  use ExUnit.Case
  doctest NervesTestClient

  test "greets the world" do
    assert NervesTestClient.hello() == :world
  end
end
