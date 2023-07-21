defmodule SippetExtrasTest do
  use ExUnit.Case
  doctest SippetExtras

  test "greets the world" do
    assert SippetExtras.hello() == :world
  end
end
