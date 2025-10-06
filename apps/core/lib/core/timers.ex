defmodule Core.Timers do
  @moduledoc """
  Simple timers GenServer. Schedule callbacks after a given delay.
  """

  use GenServer

  # Client API
  def start_link(), do: start_link([])
  def start_link(opts) when is_list(opts), do: GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))

  @doc """
  Schedule a message to be sent to `pid` with `tag` after `ms` milliseconds.
  Returns a reference that can be cancelled.

  You can target a specific timers server by name or pid with the first
  argument; defaults to the globally registered `Core.Timers`.
  """
  def schedule(server \\ __MODULE__, ms, pid, tag)
  def schedule(server, ms, pid, tag) when is_integer(ms) and is_pid(pid) do
    GenServer.call(server, {:schedule, ms, pid, tag})
  end

  def cancel(ref) when is_reference(ref) do
    GenServer.call(__MODULE__, {:cancel, ref})
  end

  # Server callbacks
  @impl true
  def init(:ok), do: {:ok, %{timers: %{}}}

  @impl true
  def handle_call({:schedule, ms, pid, tag}, _from, state) do
    ref = Process.send_after(self(), {:deliver, pid, tag}, ms)
    {:reply, ref, update_in(state, [:timers], &Map.put(&1, ref, {pid, tag}))}
  end

  def handle_call({:cancel, ref}, _from, state) do
    _ = Process.cancel_timer(ref)
    {:reply, :ok, update_in(state, [:timers], &Map.delete(&1, ref))}
  end

  @impl true
  def handle_info({:deliver, pid, tag}, state) do
    send(pid, {:timer, tag})
    {:noreply, state}
  end
end
