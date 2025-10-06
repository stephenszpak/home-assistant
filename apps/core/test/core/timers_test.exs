defmodule Core.TimersTest do
  use ExUnit.Case, async: true

  setup do
    unless Process.whereis(Ui.PubSub) do
      {:ok, _pubsub} = start_supervised({Phoenix.PubSub, name: Ui.PubSub})
    end
    :ok
  end

  test "create_timer/1 broadcasts when done" do
    {:ok, _pid} = start_supervised({Core.Timers, name: :timers_test})
    Phoenix.PubSub.subscribe(Ui.PubSub, "timers")
    assert {:ok, id} = Core.Timers.create_timer(:timers_test, 0)
    assert_receive {:timer_done, ^id}, 100
  end

  test "cancel_timer/1 prevents broadcast" do
    {:ok, _pid} = start_supervised({Core.Timers, name: :timers_test})
    Phoenix.PubSub.subscribe(Ui.PubSub, "timers")
    assert {:ok, id} = Core.Timers.create_timer(:timers_test, 1)
    assert :ok = Core.Timers.cancel_timer(:timers_test, id)
    refute_receive {:timer_done, ^id}, 200
  end

  test "list_timers/0 returns active timers" do
    {:ok, _pid} = start_supervised({Core.Timers, name: :timers_test})
    assert {:ok, id1} = Core.Timers.create_timer(:timers_test, 1)
    assert {:ok, id2} = Core.Timers.create_timer(:timers_test, 1)
    list = Core.Timers.list_timers(:timers_test)
    ids = Enum.map(list, & &1.id) |> Enum.sort()
    assert ids == Enum.sort([id1, id2])
  end
end
