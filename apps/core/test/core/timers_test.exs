defmodule Core.TimersTest do
  use ExUnit.Case, async: true

  test "schedule/3 sends a timer message" do
    {:ok, _pid} = start_supervised({Core.Timers, name: :timers_test})
    ref = Core.Timers.schedule(:timers_test, 10, self(), :hello)
    assert is_reference(ref)

    assert_receive {:timer, :hello}, 200
  end
end
