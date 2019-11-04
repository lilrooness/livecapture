defmodule SCTPDebugDump do
  use Agent
  require Logger

  def start_link() do
    Agent.start_link(
      fn ->
        0
      end,
      name: __MODULE__
    )
  end

  def log(dump) do
    Agent.update(__MODULE__, fn counter ->
      Logger.info("DEBUG - Logging SCTP packet")
      handle = File.open!("debug_logs/debug_dump_#{counter}", [:write])
      IO.binwrite(handle, dump)
      File.close(handle)
      counter + 1
    end)
  end

  def child_spec() do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
