defmodule Core.Timers do
  @moduledoc """
  Timers GenServer with create/list/cancel and PubSub broadcasts.

  - `create_timer(seconds)` -> {:ok, id}
  - `list_timers()` -> list of %{id, seconds, started_at}
  - `cancel_timer(id)` -> :ok | {:error, :not_found}
  - On completion, broadcasts `{:timer_done, id}` on PubSub topic "timers" via `Core.PubSub`.
  """

  use GenServer

  @pubsub Application.compile_env(:core, :pubsub, Ui.PubSub)
  @topic "timers"

  # Client API
  def start_link(), do: start_link([])
  def start_link(opts) when is_list(opts), do: GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))

  def create_timer(server \\ __MODULE__, seconds)
  def create_timer(server, seconds) when is_integer(seconds) and seconds >= 0 do
    GenServer.call(server, {:create_timer, seconds})
  end

  def list_timers(server \\ __MODULE__) do
    GenServer.call(server, :list)
  end

  def cancel_timer(server \\ __MODULE__, id) do
    GenServer.call(server, {:cancel, id})
  end

  # Server callbacks
  @impl true
  def init(:ok), do: {:ok, %{timers: %{}, seq: 0}}

  @impl true
  def handle_call(:list, _from, state) do
    list =
      for {id, %{seconds: s, started_at: t}} <- state.timers do
        %{id: id, seconds: s, started_at: t}
      end

    {:reply, list, state}
  end

  def handle_call({:create_timer, seconds}, _from, state) do
    id = state.seq + 1
    ms = seconds * 1000
    ref = Process.send_after(self(), {:timer_done, id}, ms)
    timer = %{id: id, seconds: seconds, started_at: System.monotonic_time(:millisecond), ref: ref}
    {:reply, {:ok, id}, %{state | seq: id, timers: Map.put(state.timers, id, timer)}}
  end

  def handle_call({:cancel, id}, _from, state) do
    case Map.pop(state.timers, id) do
      {nil, _} -> {:reply, {:error, :not_found}, state}
      {%{ref: ref}, timers} ->
        _ = Process.cancel_timer(ref)
        {:reply, :ok, %{state | timers: timers}}
    end
  end

  @impl true
  def handle_info({:timer_done, id}, state) do
    if Process.whereis(@pubsub) do
      Phoenix.PubSub.broadcast(@pubsub, @topic, {:timer_done, id})
    end
    {:noreply, update_in(state.timers, &Map.delete(&1, id))}
  end
end
